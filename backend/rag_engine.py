import re
import io
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Default University Curriculum Guidelines per Subject
DEFAULT_SUBJECT_GUIDELINES = {
    "Data Structures & Algorithms": """
    University Syllabus & Remedial Policy - Data Structures & Algorithms (DSA):
    - Policy 1: If a student's predicted score is below 70%, they must prioritize fundamental Problem Solving: Array operations, Linked Lists, Stack, and Queue implementations before midterms.
    - Policy 2: For students with low study hours (< 15 hrs/week), complete mandatory weekly coding exercises on LeetCode / HackerRank focusing on Searching & Sorting algorithms.
    - Policy 3: High-yield exam topics carry 45% weight: Binary Search Trees, Graph Traversals (BFS/DFS), and Dynamic Programming. Focus 10 hours of revision on DP memoization.
    - Policy 4: Students with attendance < 80% must attend weekly remedial lab tutorial sessions to cover missed algorithmic code walk-throughs.
    """,
    "Artificial Intelligence": """
    University Syllabus & Remedial Policy - Artificial Intelligence (AI):
    - Policy 1: If a student's predicted score is below 70%, review foundational Mathematics: Linear Algebra (matrix operations), Probability & Statistics, and Multivariate Calculus.
    - Policy 2: Mandatory hands-on lab policy: Complete mini-projects using Python (Scikit-Learn, PyTorch, or TensorFlow) covering Supervised Learning classification & regression models.
    - Policy 3: High-yield exam topics carry 50% weight: Neural Network Backpropagation, Decision Trees, Random Forests, and Search Algorithms (A* and Minimax).
    - Policy 4: Students falling behind should utilize interactive Google Colab notebooks and university online video lectures for deep learning architectures.
    """,
    "Cloud Computing": """
    University Syllabus & Remedial Policy - Cloud Computing:
    - Policy 1: If a student's predicted score is below 70%, focus on core Cloud Fundamentals: Virtualization, IaaS/PaaS/SaaS service models, and Cloud Storage paradigms.
    - Policy 2: Practical Lab requirement: Complete hands-on tutorials on AWS / GCP / Azure free tier involving EC2 instance setup, Virtual Private Clouds (VPC), and IAM security policies.
    - Policy 3: High-yield exam topics carry 45% weight: Docker containerization, Kubernetes cluster orchestration, Microservices architecture, and Serverless computing (AWS Lambda).
    - Policy 4: Students needing score improvement must review cloud security compliance, encryption standards, and load balancing algorithms.
    """
}

# In-memory index of subject chunks: { subject: [chunk1, chunk2, ...] }
_SUBJECT_CHUNKS = {}


def _chunk_text(text: str, chunk_size: int = 250) -> list[str]:
    """Splits document text into clean semantic chunks."""
    sentences = re.split(r'(?<=[.!?\n]) +', text.strip())
    chunks = []
    current_chunk = ""

    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        if len(current_chunk) + len(sentence) <= chunk_size:
            current_chunk += " " + sentence if current_chunk else sentence
        else:
            if current_chunk:
                chunks.append(current_chunk)
            current_chunk = sentence

    if current_chunk:
        chunks.append(current_chunk)

    return chunks if chunks else [text]


_CUSTOM_SUBJECTS = set()


def initialize_rag():
    """Initializes RAG index with default university curriculum guidelines."""
    global _SUBJECT_CHUNKS
    for subject, text in DEFAULT_SUBJECT_GUIDELINES.items():
        if subject not in _SUBJECT_CHUNKS or not _SUBJECT_CHUNKS[subject]:
            _SUBJECT_CHUNKS[subject] = _chunk_text(text)


def index_document_text(subject: str, text: str, append: bool = False):
    """Indexes text content for a subject, replacing defaults with teacher's custom guidelines."""
    initialize_rag()
    new_chunks = _chunk_text(text)
    if append and subject in _SUBJECT_CHUNKS:
        _SUBJECT_CHUNKS[subject].extend(new_chunks)
    else:
        _SUBJECT_CHUNKS[subject] = new_chunks
    _CUSTOM_SUBJECTS.add(subject)


def parse_pdf_bytes(pdf_bytes: bytes) -> str:
    """Extracts plain text from uploaded PDF bytes using pypdf."""
    try:
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
    RAG Retriever: Uses TF-IDF & Cosine Similarity to find top university curriculum rules.
    Prioritizes custom teacher guidelines uploaded for the subject.
    """
    initialize_rag()
    chunks = _SUBJECT_CHUNKS.get(subject, [])
    if not chunks:
        chunks = _SUBJECT_CHUNKS.get("Data Structures & Algorithms", [])
    if not chunks:
        return []

    # If teacher uploaded custom guidelines for this subject, return the teacher's guidelines directly
    if subject in _CUSTOM_SUBJECTS or len(chunks) <= top_k:
        results = []
        for c in chunks[:top_k]:
            clean_chunk = c.strip()
            if clean_chunk:
                if clean_chunk.startswith("🎓"):
                    results.append(clean_chunk)
                else:
                    results.append(f"🎓 UNIVERSITY GUIDELINE: {clean_chunk}")
        return results

    # Fallback to TF-IDF retrieval for multi-chunk documents
    attendance = student_data.get("Attendance", 85.0)
    hours = student_data.get("Hours_Studied", 15.0)
    prev_score = student_data.get("Previous_Scores_Semester_Wise", 75.0)

    query_keywords = [subject]
    if predicted_score < 70:
        query_keywords.extend(["predicted score below 70%", "score low", "remedial policy", "failing"])
    if attendance < 80:
        query_keywords.extend(["attendance", "missed lab", "remedial tutorial"])
    if hours < 15:
        query_keywords.extend(["low study hours", "practice", "exercise"])
    if prev_score < 70:
        query_keywords.extend(["fundamentals", "revision"])

    query_str = " ".join(query_keywords)

    try:
        vectorizer = TfidfVectorizer().fit(chunks + [query_str])
        chunk_vectors = vectorizer.transform(chunks)
        query_vector = vectorizer.transform([query_str])

        similarities = cosine_similarity(query_vector, chunk_vectors).flatten()
        top_indices = similarities.argsort()[::-1][:top_k]

        results = []
        for idx in top_indices:
            clean_chunk = chunks[idx].strip()
            if clean_chunk:
                prefix = "" if clean_chunk.startswith("🎓") else "🎓 UNIVERSITY GUIDELINE: "
                results.append(f"{prefix}{clean_chunk}")

        return results if results else [f"🎓 UNIVERSITY GUIDELINE: {c.strip()}" for c in chunks[:top_k]]
    except Exception as e:
        print(f"RAG retrieval error: {e}")
        return [f"🎓 UNIVERSITY GUIDELINE: {c.strip()}" for c in chunks[:top_k]]


# Initialize default guidelines on module import
initialize_rag()
