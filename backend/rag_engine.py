import re
import io
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# Default Curated Educational Corpus per Subject
DEFAULT_SUBJECT_GUIDELINES = {
    "Data Structures & Algorithms": """
    Prioritize core Linear Data Structures: master array manipulations, singly and doubly linked lists, stack-based expression evaluation, and queue implementations before progressing to non-linear structures.
    Implement tree-based algorithms from scratch: practice Binary Search Tree (BST) insertion, deletion, and lowest common ancestor, followed by Heap and Priority Queue applications.
    Master high-yield graph traversal techniques: implement Breadth-First Search (BFS) for shortest path problems and Depth-First Search (DFS) with backtracking for cycle detection.
    Formulate dynamic programming solutions methodically: start with top-down memoization, identify sub-problem recurrence relations, and convert to bottom-up tabulation for optimal space efficiency.
    Conduct weekly timed mock coding sessions focusing on time and space complexity analysis (Big-O notation) and searching & sorting algorithms (QuickSort, MergeSort, Binary Search).
    For students with attendance or lab deficits, complete missed programming lab exercises and attend peer tutoring sessions to rebuild fundamental conceptual mastery.
    Advance to competitive programming problem sets involving Trie structures, Disjoint Set Union (DSU), Segment Trees, and advanced graph algorithms (Dijkstra's, Floyd-Warshall).
    Review previous semester exam papers and university question banks, analyzing common pitfalls in recursion limits, pointer manipulations, and edge-case handling.
    """,
    "Artificial Intelligence": """
    Reinforce mathematical foundations essential for AI: review Multivariable Calculus, Linear Algebra matrix transformations, and Bayes' Theorem conditional probability distributions.
    Build end-to-end Supervised Learning pipelines in Python using Scikit-Learn: practice data preprocessing, feature scaling, Cross-Validation, and hyperparameter tuning with GridSearchCV.
    Master fundamental classification and regression models: analyze Decision Trees, Random Forests, Support Vector Machines (SVM), and Logistic Regression decision boundaries.
    Deconstruct Artificial Neural Networks: calculate gradient updates through manual backpropagation derivations and implement multi-layer perceptrons with non-linear activation functions.
    Study heuristic search algorithms in state-space graphs: implement A* search with admissible heuristics, Minimax game trees with Alpha-Beta pruning, and hill-climbing optimization.
    For students experiencing concept gaps, participate in weekly AI laboratory remedial sessions and implement core algorithms from first principles without external libraries.
    Advance to modern Deep Learning paradigms: study Convolutional Neural Networks (CNN) for image recognition, Recurrent Neural Networks (RNN/LSTM) for sequential data, and Transformer self-attention.
    Examine ethical AI principles, model interpretability with SHAP/LIME values, and regularization techniques (Dropout, L1/L2 ridge/lasso) to prevent model overfitting.
    """,
    "Cloud Computing": """
    Grasp foundational Cloud Architecture principles: differentiate between IaaS, PaaS, and SaaS models, shared responsibility security frameworks, and multi-tenant virtualization.
    Complete hands-on infrastructure provisioning on AWS/Azure/GCP: configure Virtual Private Clouds (VPC), public/private subnets, Internet Gateways, NAT Gateways, and Route Tables.
    Implement robust Cloud Security and Governance: create granular Identity and Access Management (IAM) role-based access policies, multi-factor authentication, and KMS encryption keys.
    Master containerization technologies: write Dockerfiles following multi-stage build best practices, manage container lifecycle, and compose multi-container application stacks.
    Study scalable Kubernetes cluster orchestration: deploy Pods, Services, Ingress controllers, and configure Horizontal Pod Autoscalers (HPA) for automated traffic handling.
    For students with lab attendance shortfalls, replicate practical cloud networking and EC2 compute deployment tutorials through guided cloud sandboxes and interactive labs.
    Explore Serverless architectures and Event-Driven Design: build microservices with AWS Lambda, API Gateway, DynamoDB, and asynchronous messaging queues (SQS/SNS).
    Review Disaster Recovery strategies, High Availability multi-region replication, and FinOps cost optimization strategies across enterprise cloud deployments.
    """
}

# In-memory index of subject chunks: { subject: [chunk1, chunk2, ...] }
_SUBJECT_CHUNKS = {}
_CUSTOM_SUBJECTS = set()


def is_valid_recommendation_chunk(text: str) -> bool:
    """Filters out document titles, module/chapter headers, divider lines, and non-actionable metadata."""
    t = text.strip()
    if not t:
        return False
    # Reject decorative divider lines (e.g. ====, ----, ****)
    if re.match(r'^[=\-_*#~]{3,}$', t):
        return False
    # Reject module, chapter, unit, section, part headings
    if re.match(r'^(module|chapter|unit|section|part)\s+\d+[\s\:\-]', t, re.IGNORECASE):
        return False
    # Reject institutional / departmental syllabus headings
    if re.match(r'^(department of|faculty of|university of|course code|syllabus|curriculum|academic year)[\s\:\-]', t, re.IGNORECASE):
        return False
    # Reject lines containing 'guidelines:' or 'syllabus:' if short
    if any(k in t.lower() for k in ['guidelines:', 'syllabus:', 'learning outcomes:']) and len(t.split()) <= 14:
        return False
    # Reject uppercase headers without sentence endings
    if t.isupper() and len(t.split()) <= 12 and not t.endswith('.'):
        return False
    # Reject lines that end with a colon (e.g. 'MODULE 1:')
    if t.endswith(':'):
        return False
    # Must have reasonable instructional length
    words = t.split()
    if len(words) < 5 or len(t) < 25:
        return False
    return True


def _chunk_text(text: str, chunk_size: int = 250) -> list[str]:
    """Splits document text into clean, individual recommendation sentences, filtering headers and metadata."""
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
            if s and is_valid_recommendation_chunk(s):
                chunks.append(s)

    return chunks if chunks else [c.strip() for c in raw_lines if is_valid_recommendation_chunk(c)]


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
    print(f"RAG Engine: Indexed {len(new_chunks)} custom chunks for subject '{norm_subj}'.")


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
    RAG Retriever: Uses TF-IDF embeddings and Cosine Similarity over curated educational corpus.
    Prioritizes teacher custom uploaded guidelines when available and filters metadata headers.
    """
    initialize_rag()
    norm_subj = _normalize_subject(subject)
    chunks = _SUBJECT_CHUNKS.get(norm_subj, [])
    if not chunks:
        chunks = _SUBJECT_CHUNKS.get("Data Structures & Algorithms", [])
    if not chunks:
        return []

    def clean_text(c: str) -> str:
        text = (
            c.replace("🎓 UNIVERSITY GUIDELINE:", "")
            .replace("🎓", "")
            .replace("DSA FOCUS:", "")
            .replace("AI FOCUS:", "")
            .replace("CLOUD FOCUS:", "")
            .strip()
        )
        text = re.sub(r'^[\s\-\*\•\d\.\)\:]+', '', text).strip()
        return text

    cleaned_chunks = [clean_text(c) for c in chunks if is_valid_recommendation_chunk(clean_text(c))]
    if not cleaned_chunks:
        cleaned_chunks = [clean_text(c) for c in chunks if clean_text(c)]
    if not cleaned_chunks:
        return []

    # If teacher uploaded custom guidelines and they are few, return them directly
    if norm_subj in _CUSTOM_SUBJECTS and len(cleaned_chunks) <= top_k:
        return cleaned_chunks

    attendance = float(student_data.get("Attendance") or student_data.get("attendance") or 85.0)
    hours = float(student_data.get("Hours_Studied") or student_data.get("hoursStudied") or 15.0)
    prev_score = float(student_data.get("Previous_Scores_Semester_Wise") or student_data.get("previousScore") or 75.0)
    resources = int(student_data.get("Access_to_Resources") if student_data.get("Access_to_Resources") is not None else student_data.get("accessToResources") or 2)
    disability = int(student_data.get("Learning_Disabilities") if student_data.get("Learning_Disabilities") is not None else student_data.get("learningDisabilities") or 0)
    income = int(student_data.get("Family_Income") if student_data.get("Family_Income") is not None else student_data.get("familyIncome") or 1)

    # Construct rich semantic search query representing student's specific academic deficits
    query_parts = []

    if predicted_score < 60:
        query_parts.append("remedial foundation core basics rebuild concept gaps prerequisite tutoring peer study missed exam recovery")
    elif predicted_score < 75:
        query_parts.append("core fundamentals practice exercises structured revision problem solving exam question banks mock coding")
    else:
        query_parts.append("advanced honors complex optimization competitive mastery architectural patterns deep learning hackathons")

    if attendance < 80:
        query_parts.append("attendance lab practical deficit missed exercises peer tutoring compliance catch up")

    if hours < 14:
        query_parts.append("study hours weekly timed sessions dedicated problem sets practice discipline pomodoro sprints")

    if prev_score < 70:
        query_parts.append("prerequisite modules fundamental concepts review previous semester gaps discrete mathematics")

    if resources == 0:
        query_parts.append("limited access resources offline compiler campus library textbook reserves workbooks open lab")

    if disability == 1:
        query_parts.append("learning disabilities visual algorithm animations pseudo-code breakdowns structured accommodations")

    if income == 0:
        query_parts.append("free open source fee waived community borrowing")

    query_str = " ".join(query_parts) if query_parts else "core fundamentals practice exercises structured revision problem solving"

    try:
        # Full TF-IDF Vectorization with unigram and bigram n-grams and sublinear TF scaling
        vectorizer = TfidfVectorizer(
            ngram_range=(1, 2),
            sublinear_tf=True,
            stop_words="english"
        ).fit(cleaned_chunks + [query_str])

        chunk_vectors = vectorizer.transform(cleaned_chunks)
        query_vector = vectorizer.transform([query_str])

        similarities = cosine_similarity(query_vector, chunk_vectors).flatten()
        top_indices = similarities.argsort()[::-1]

        results = []
        for idx in top_indices:
            candidate = cleaned_chunks[idx]
            if candidate not in results and is_valid_recommendation_chunk(candidate):
                results.append(candidate)
            if len(results) >= top_k:
                break

        return results if results else cleaned_chunks[:top_k]
    except Exception as e:
        print(f"RAG retrieval error: {e}")
        return cleaned_chunks[:top_k]



# Initialize default guidelines on module import
initialize_rag()
