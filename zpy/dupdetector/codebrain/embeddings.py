import numpy as np

# --------------------------------------------------
# LAZY MODEL LOADING
# --------------------------------------------------

_model = None


def get_model():
    global _model

    if _model is None:
        from sentence_transformers import SentenceTransformer
        print("⚡ Loading embedding model (one-time)...")
        _model = SentenceTransformer("all-MiniLM-L6-v2")

    return _model


# --------------------------------------------------
# EMBEDDING FUNCTION
# --------------------------------------------------

def embed(text: str):
    model = get_model()
    return model.encode(text)


# --------------------------------------------------
# SIMILARITY
# --------------------------------------------------

def cosine_similarity(a, b):
    a = np.array(a)
    b = np.array(b)

    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
