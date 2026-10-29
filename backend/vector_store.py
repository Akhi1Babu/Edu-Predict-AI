"""
EduPredict AI - Persistent Vector Store & PDF Ingestion Engine
Handles:
1. PDF document parsing and text extraction using pypdf.
2. Intelligent chunking with metadata header filtering and chunk overlaps.
3. Dense vector embeddings (L2-normalized semantic feature vectors).
4. Persistent on-disk vector storage with subject isolation and cosine similarity retrieval.
"""

import os
import io
import re
import json
import numpy as np
from datetime import datetime
from typing import List, Dict, Any, Optional

try:
    import pypdf
    PYPDF_AVAILABLE = True
except ImportError:
    PYPDF_AVAILABLE = False


def is_valid_chunk(text: str) -> bool:
    """Filters out document titles, decorative dividers, and syllabus section headers."""
    t = text.strip()
    if not t:
        return False
    # Divider lines
    if re.match(r'^[=\-_*#~]{3,}$', t):
        return False
    # Module/Unit/Chapter headings
    if re.match(r'^(module|chapter|unit|section|part)\s+\d+[\s\:\-]', t, re.IGNORECASE):
        return False
    # Institutional / Departmental headers
    if re.match(r'^(department of|faculty of|university of|course code|syllabus|curriculum|academic year)[\s\:\-]', t, re.IGNORECASE):
        return False
    # Short lines ending with colon
    if t.endswith(':') and len(t.split()) < 15:
        return False
    # Uppercase headers without periods
    if t.isupper() and len(t.split()) <= 12 and not t.endswith('.'):
        return False
    # Minimum instructional length
    words = t.split()
    if len(words) < 5 or len(t) < 25:
        return False
    return True


class VectorStore:
    def __init__(self, storage_path: Optional[str] = None):
        if storage_path is None:
            storage_path = os.path.join(os.path.dirname(__file__), "data", "vector_store.json")
        self.storage_path = storage_path
        os.makedirs(os.path.dirname(self.storage_path), exist_ok=True)
        
        # In-memory index: list of dicts with {id, subject, text, vector, metadata}
        self.documents: List[Dict[str, Any]] = []
        self._vocabulary: Dict[str, int] = {}
        self._idf: Dict[str, float] = {}
        self.load()

    def parse_pdf(self, pdf_bytes: bytes) -> str:
        """Extracts text from PDF bytes page-by-page."""
        if not PYPDF_AVAILABLE:
            raise ImportError("pypdf is not installed. Please install pypdf via 'pip install pypdf'.")
        
        reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
        pages_text = []
        for idx, page in enumerate(reader.pages):
            page_text = page.extract_text() or ""
            if page_text.strip():
                pages_text.append(page_text.strip())
        return "\n\n".join(pages_text)

    def chunk_text(self, text: str) -> List[str]:
        """Splits document text into valid recommendation sentences/chunks."""
        raw_lines = re.split(r'[\r\n]+', text.strip())
        chunks = []
        for line in raw_lines:
            line = line.strip()
            if not line:
                continue
            # Split line into sentences if it is a large paragraph
            sentences = re.split(r'(?<=[.!?])\s+', line)
            for s in sentences:
                s = s.strip()
                s = re.sub(r'^[\s\-\*\•\d\.\)\:]+', '', s).strip()
                if s and is_valid_chunk(s):
                    chunks.append(s)
        return chunks if chunks else [c.strip() for c in raw_lines if is_valid_chunk(c)]

    def _tokenize(self, text: str) -> List[str]:
        """Basic alphanumeric unigram and bigram tokenization."""
        words = re.findall(r'\b[a-zA-Z]{3,}\b', text.lower())
        # Filter common stopwords
        stopwords = {
            'the', 'and', 'for', 'that', 'this', 'with', 'from', 'have', 'were',
            'which', 'will', 'are', 'should', 'must', 'can', 'has', 'had', 'been',
            'into', 'then', 'them', 'they', 'what', 'when', 'where', 'who', 'how'
        }
        filtered = [w for w in words if w not in stopwords]
        bigrams = [f"{filtered[i]}_{filtered[i+1]}" for i in range(len(filtered)-1)]
        return filtered + bigrams

    def _build_vocab_and_idf(self):
        """Builds vocabulary and inverse document frequency (IDF) weights across all stored chunks."""
        if not self.documents:
            self._vocabulary = {}
            self._idf = {}
            return

        doc_count = len(self.documents)
        df_count: Dict[str, int] = {}
        for doc in self.documents:
            tokens = set(self._tokenize(doc["text"]))
            for t in tokens:
                df_count[t] = df_count.get(t, 0) + 1

        self._vocabulary = {term: idx for idx, term in enumerate(df_count.keys())}
        self._idf = {
            term: float(np.log((1 + doc_count) / (1 + count)) + 1.0)
            for term, count in df_count.items()
        }

    def _embed(self, text: str) -> List[float]:
        """Computes sublinear L2-normalized TF-IDF dense embedding vector."""
        if not self._vocabulary:
            return []
        
        vec = np.zeros(len(self._vocabulary), dtype=np.float32)
        tokens = self._tokenize(text)
        if not tokens:
            return vec.tolist()

        tf: Dict[str, int] = {}
        for t in tokens:
            if t in self._vocabulary:
                tf[t] = tf.get(t, 0) + 1

        for term, count in tf.items():
            idx = self._vocabulary[term]
            sublinear_tf = 1.0 + np.log(count)
            vec[idx] = sublinear_tf * self._idf.get(term, 1.0)

        norm = np.linalg.norm(vec)
        if norm > 0:
            vec = vec / norm
        return vec.tolist()

    def add_document(self, subject: str, text: str, source_filename: str = "manual_entry") -> int:
        """
        Chunks text, indexes vectors, and saves to persistent store.
        Replaces existing custom chunks for this subject to ensure fresh guidelines.
        """
        chunks = self.chunk_text(text)
        if not chunks:
            return 0

        # Remove previous custom chunks for this specific subject to allow clean updates
        self.documents = [d for d in self.documents if d.get("subject") != subject]

        timestamp = datetime.utcnow().isoformat()
        for i, chunk in enumerate(chunks):
            doc_entry = {
                "id": f"{subject}_{i}_{int(datetime.utcnow().timestamp())}",
                "subject": subject,
                "text": chunk,
                "metadata": {
                    "source": source_filename,
                    "chunk_index": i,
                    "created_at": timestamp
                }
            }
            self.documents.append(doc_entry)

        # Re-compute vocabulary, IDF, and update embeddings for all documents
        self._build_vocab_and_idf()
        for doc in self.documents:
            doc["vector"] = self._embed(doc["text"])

        self.save()
        print(f"[VectorStore] Indexed {len(chunks)} chunks for '{subject}' (Source: {source_filename}).")
        return len(chunks)

    def ingest_pdf(self, subject: str, pdf_bytes: bytes, filename: str = "curriculum.pdf") -> Dict[str, Any]:
        """Full pipeline: PDF ingestion -> Text extraction -> Chunking -> Vector embedding -> Storage."""
        raw_text = self.parse_pdf(pdf_bytes)
        chunk_count = self.add_document(subject=subject, text=raw_text, source_filename=filename)
        return {
            "status": "success",
            "subject": subject,
            "filename": filename,
            "extracted_characters": len(raw_text),
            "chunks_indexed": chunk_count
        }

    def search(self, subject: str, query_text: str, predicted_score: float = 75.0, top_k: int = 3) -> List[str]:
        """
        Cosine similarity search over stored vectors with score consistency checks.
        """
        subject_docs = [d for d in self.documents if d.get("subject") == subject]
        if not subject_docs:
            # Fallback to any documents if subject has none
            subject_docs = self.documents

        if not subject_docs:
            return []

        query_vec = np.array(self._embed(query_text), dtype=np.float32)
        if len(query_vec) == 0 or np.linalg.norm(query_vec) == 0:
            return [d["text"] for d in subject_docs[:top_k]]

        scored_candidates = []
        for doc in subject_docs:
            doc_vec = np.array(doc.get("vector") or [], dtype=np.float32)
            if len(doc_vec) == len(query_vec) and np.linalg.norm(doc_vec) > 0:
                similarity = float(np.dot(query_vec, doc_vec))
            else:
                similarity = 0.0
            scored_candidates.append((similarity, doc["text"]))

        # Sort descending by cosine similarity
        scored_candidates.sort(key=lambda x: x[0], reverse=True)

        results = []
        for sim, text in scored_candidates:
            if text not in results and self._is_consistent_with_score(text, predicted_score):
                results.append(text)
            if len(results) >= top_k:
                break

        # Fallback if filtered list is too short
        if len(results) < top_k:
            for sim, text in scored_candidates:
                if text not in results:
                    results.append(text)
                if len(results) >= top_k:
                    break

        return results

    def _is_consistent_with_score(self, chunk: str, score: float) -> bool:
        lower = chunk.lower()
        if score >= 75.0:
            remedial_markers = [
                'low academic exam', 'remedial makeup', 'underperforming',
                'score below 60', 'below 60 percent', 'predicted to score below 60',
                'remedial foundation', 'severe academic deficit'
            ]
            if any(m in lower for m in remedial_markers):
                return False
        elif score < 60.0:
            advanced_markers = [
                'exceeding 80 percent', 'high-performing honors', 'advanced honors',
                'accelerated high-scoring'
            ]
            if any(m in lower for m in advanced_markers):
                return False
        return True

    def save(self):
        """Persists the vector store to disk as JSON."""
        data = {
            "version": "1.0",
            "updated_at": datetime.utcnow().isoformat(),
            "vocabulary": self._vocabulary,
            "idf": self._idf,
            "documents": self.documents
        }
        with open(self.storage_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def load(self):
        """Loads persistent vectors and vocabulary from disk if present."""
        if os.path.exists(self.storage_path):
            try:
                with open(self.storage_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._vocabulary = data.get("vocabulary", {})
                    self._idf = data.get("idf", {})
                    self.documents = data.get("documents", [])
                print(f"[VectorStore] Loaded {len(self.documents)} vectors from {self.storage_path}.")
            except Exception as e:
                print(f"[VectorStore] Notice loading vector store: {e}")
                self.documents = []


# Singleton instance for app-wide use
vector_store = VectorStore()
