import re
import io
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Default Curriculum Recommendations per Subject
DEFAULT_SUBJECT_GUIDELINES = {
    "Data Structures & Algorithms": """
    If predicted score is below 70%, prioritize core Data Structures: Arrays, Linked Lists, Stacks, Queues, and Trees.
    If predicted score is 70% or above, advance your skills with complex topics: Graph Traversals (BFS/DFS), Dynamic Programming, and Trie data structures.
    Complete weekly algorithmic practice exercises focusing on Searching & Sorting algorithms and time complexity.
    Solve previous exam questions and practice competitive coding problems regularly.
    """,
    "Artificial Intelligence": """
    If predicted score is below 70%, review foundational Linear Algebra, Probability, and basic Machine Learning algorithms.
    If predicted score is 70% or above, explore advanced AI topics: Neural Network Backpropagation, Convolutional Architectures, and Reinforcement Learning.
    Complete hands-on lab exercises in Python covering Supervised Learning classification & regression models.
    Focus revision on core exam topics: Decision Trees, Random Forests, and Search Algorithms (A* & Heuristics).
    """,
    "Cloud Computing": """
    If predicted score is below 70%, focus on Cloud Fundamentals: Virtualization, IaaS/PaaS/SaaS service models, and Storage paradigms.
    If predicted score is 70% or above, deep-dive into advanced Cloud Architecture: Microservices, Distributed Systems, and Serverless computing.
    Complete practical hands-on tutorials on AWS/GCP/Azure involving EC2 instances, Virtual Private Clouds (VPC), and IAM security policies.
    Focus revision on key exam topics: Docker containerization, Kubernetes cluster orchestration, and Cloud Security.
    """
}

# In-memory index of subject chunks: { subject: [chunk1, chunk2, ...] }
_SUBJECT_CHUNKS = {}
_CUSTOM_SUBJECTS = set()


def _chunk_text(text: str, chunk_size: int = 250) -> list[str]:
    """Splits document text into clean, individual recommendation sentences."""
    raw_lines = re.split(r'[\r\n]+', text.strip())
    chunks = []

    for line in raw_lines:
        line = line.strip()
        if not line:
            continue
        line = re.sub(r'^[\s\-\*\•\d\.\)\:]+', '', line).strip()
        if not line:
            continue

        sentences = re.split(r'(?<=[.!?]) +', line)
        for s in sentences:
            s = s.strip()
            s = re.sub(r'^[\s\-\*\•\d\.\)\:]+', '', s).strip()
            if s and len(s) > 5:
                chunks.append(s)

    return chunks if chunks else [text.strip()]


def _normalize_subject(subject: str) -> str:
    if not subject:
        return "Data Structures & Algorithms"
    s = subject.strip().lower()
    if "data" in s or "dsa" in s or "structure" in s or "algorithm" in s:
        return "Data Structures & Algorithms"
    if "ai" in s or "artificial" in s or "intelligence" in s:
        return "Artificial Intelligence"
    if "cloud" in s or "aws" in s or "computing" in s:
        return "Cloud Computing"
    return subject.strip()


def initialize_rag():
    """Initializes RAG index with default curriculum recommendations."""
    global _SUBJECT_CHUNKS
    for subject, text in DEFAULT_SUBJECT_GUIDELINES.items():
        norm_subj = _normalize_subject(subject)
        if norm_subj not in _SUBJECT_CHUNKS or not _SUBJECT_CHUNKS[norm_subj]:
            _SUBJECT_CHUNKS[norm_subj] = _chunk_text(text)


def index_document_text(subject: str, text: str, append: bool = False):
    """Indexes text content for a subject, replacing defaults with teacher's custom guidelines."""
    initialize_rag()
    norm_subj = _normalize_subject(subject)
    new_chunks = _chunk_text(text)
    if append and norm_subj in _SUBJECT_CHUNKS:
        _SUBJECT_CHUNKS[norm_subj].extend(new_chunks)
    else:
        _SUBJECT_CHUNKS[norm_subj] = new_chunks
    _CUSTOM_SUBJECTS.add(norm_subj)


def parse_pdf_bytes(pdf_bytes: bytes) -> str:
    """Extracts plain text from uploaded PDF bytes using pypdf."""
    try:
        # pyrefly: ignore [missing-import]
        import pypdf
        reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
        extracted_text = []
        for page in reader.pages:
            t = page.extract_text()
            if t:
                extracted_text.append(t)
        return "\n".join(extracted_text)
    except Exception as e:
        print(f"PDF extraction error: {e}")
        return ""


def retrieve_university_guidelines(subject: str, student_data: dict, predicted_score: float, top_k: int = 3) -> list[str]:
    """
    RAG Retriever: Uses TF-IDF & Cosine Similarity to find top curriculum recommendations.
    Filters out conditional recommendations that do not match the student's current performance metrics.
    """
    initialize_rag()
    norm_subj = _normalize_subject(subject)
    chunks = _SUBJECT_CHUNKS.get(norm_subj, [])
    if not chunks:
        chunks = _SUBJECT_CHUNKS.get("Data Structures & Algorithms", [])
    if not chunks:
        return []

    def clean_text(c: str) -> str:
        text = c.replace("🎓 UNIVERSITY GUIDELINE:", "").replace("🎓", "").replace("DSA FOCUS:", "").replace("AI FOCUS:", "").replace("CLOUD FOCUS:", "").strip()
        text = re.sub(r'^[\s\-\*\•\d\.\)\:]+', '', text).strip()
        return text

    cleaned_chunks = [clean_text(c) for c in chunks if clean_text(c)]
    if not cleaned_chunks:
        return []

    attendance = student_data.get("Attendance", 85.0)
    hours = student_data.get("Hours_Studied", 15.0)
    prev_score = student_data.get("Previous_Scores_Semester_Wise", 75.0)

    # Filter chunks based on student data metrics
    eligible_chunks = []
    for c in cleaned_chunks:
        c_lower = c.lower()
        
        # Low score condition (<70%) -> skip if student is scoring >= 70
        if ("below 70%" in c_lower or "score < 70" in c_lower or "scoring below 70" in c_lower) and predicted_score >= 70:
            continue
            
        # High score condition (>=70%) -> skip if student is scoring < 70
        if ("70% or above" in c_lower or "score >= 70" in c_lower or "scoring above 70" in c_lower) and predicted_score < 70:
            continue

        # Low attendance condition (<80%) -> skip if attendance is good (>=80)
        if ("attendance below" in c_lower or "attendance < 80" in c_lower or "missed lab" in c_lower) and attendance >= 80:
            continue

        # Low study hours condition (<15) -> skip if study hours are sufficient (>=15)
        if ("hours < 15" in c_lower or "study hours below" in c_lower) and hours >= 15:
            continue

        eligible_chunks.append(c)

    if not eligible_chunks:
        eligible_chunks = cleaned_chunks

    if len(eligible_chunks) <= top_k:
        return eligible_chunks[:top_k]

    query_keywords = [norm_subj]
    if predicted_score < 70:
        query_keywords.extend(["below 70%", "score low", "remedial", "failing", "core", "fundamentals"])
    else:
        query_keywords.extend(["70% or above", "advanced", "mastery", "complex", "high performance"])

    if attendance < 80:
        query_keywords.extend(["attendance", "missed lab", "remedial tutorial", "lectures"])
    if hours < 15:
        query_keywords.extend(["low study hours", "practice", "exercise", "daily"])
    if prev_score < 70:
        query_keywords.extend(["fundamentals", "revision", "basic"])

    query_str = " ".join(query_keywords)

    try:
        vectorizer = TfidfVectorizer().fit(eligible_chunks + [query_str])
        chunk_vectors = vectorizer.transform(eligible_chunks)
        query_vector = vectorizer.transform([query_str])

        similarities = cosine_similarity(query_vector, chunk_vectors).flatten()
        top_indices = similarities.argsort()[::-1][:top_k]

        results = []
        for idx in top_indices:
            if eligible_chunks[idx] not in results:
                results.append(eligible_chunks[idx])

        return results if results else eligible_chunks[:top_k]
    except Exception as e:
        print(f"RAG retrieval error: {e}")
        return eligible_chunks[:top_k]


# Initialize default guidelines on module import
initialize_rag()


