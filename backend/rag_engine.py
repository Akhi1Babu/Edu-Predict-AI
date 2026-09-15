import re
import io
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Default Curriculum Recommendations per Subject
DEFAULT_SUBJECT_GUIDELINES = {
    "Data Structures & Algorithms": """
    If predicted score is below 70%, prioritize core Data Structures: Arrays, Linked Lists, Stacks, Queues, and Trees.
    Complete weekly algorithmic practice exercises focusing on Searching & Sorting algorithms.
    Focus revision on high-yield exam topics: Binary Search Trees, Graph Traversals (BFS/DFS), and Dynamic Programming.
    """,
    "Artificial Intelligence": """
    If predicted score is below 70%, review foundational Linear Algebra, Probability, and Machine Learning algorithms.
    Complete hands-on lab exercises in Python covering Supervised Learning classification & regression models.
    Focus revision on core exam topics: Neural Network Backpropagation, Decision Trees, Random Forests, and Search Algorithms.
    """,
    "Cloud Computing": """
    If predicted score is below 70%, focus on Cloud Fundamentals: Virtualization, IaaS/PaaS/SaaS service models, and Storage paradigms.
    Complete practical hands-on tutorials on AWS/GCP/Azure involving EC2 instances, Virtual Private Clouds (VPC), and IAM security policies.
    Focus revision on key exam topics: Docker containerization, Kubernetes cluster orchestration, and Serverless computing.
    """
}

# In-memory index of subject chunks: { subject: [chunk1, chunk2, ...] }
_SUBJECT_CHUNKS = {}
_CUSTOM_SUBJECTS = set()


def _chunk_text(text: str, chunk_size: int = 250) -> list[str]:
    """Splits document text into clean semantic recommendation chunks."""
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


def initialize_rag():
    """Initializes RAG index with default curriculum recommendations."""
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
    RAG Retriever: Uses TF-IDF & Cosine Similarity to find top curriculum recommendations.
    Returns clean recommendation strings without prefixes.
    """
    initialize_rag()
    chunks = _SUBJECT_CHUNKS.get(subject, [])
    if not chunks:
        chunks = _SUBJECT_CHUNKS.get("Data Structures & Algorithms", [])
    if not chunks:
        return []

    # Helper to clean up any unwanted prefixes
    def clean_text(c: str) -> str:
        return c.replace("🎓 UNIVERSITY GUIDELINE:", "").replace("🎓", "").replace("DSA FOCUS:", "").replace("AI FOCUS:", "").replace("CLOUD FOCUS:", "").strip()

    # If teacher uploaded custom guidelines for this subject, return the teacher's guidelines directly
    if subject in _CUSTOM_SUBJECTS or len(chunks) <= top_k:
        results = []
        for c in chunks[:top_k]:
            clean_chunk = clean_text(c)
            if clean_chunk:
                results.append(clean_chunk)
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
            clean_chunk = clean_text(chunks[idx])
            if clean_chunk:
                results.append(clean_chunk)

        return results if results else [clean_text(c) for c in chunks[:top_k]]
    except Exception as e:
        print(f"RAG retrieval error: {e}")
        return [clean_text(c) for c in chunks[:top_k]]


# Initialize default guidelines on module import
initialize_rag()
