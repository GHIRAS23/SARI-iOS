import hashlib,json,sys
from pathlib import Path
if len(sys.argv)!=5:
    print("Usage: python generate_manifest.py MODEL.gguf FIQH_PAGES.sqlite3 MODEL_URL LIBRARY_URL");raise SystemExit(2)
model,lib=Path(sys.argv[1]),Path(sys.argv[2])
def sha(p):
    h=hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):h.update(b)
    return h.hexdigest()
print(json.dumps({
 "version":"1.0.0-qwen35-2b",
 "modelURL":sys.argv[3],"modelSHA256":sha(model),"modelBytes":model.stat().st_size,
 "libraryURL":sys.argv[4],"librarySHA256":sha(lib),"libraryBytes":lib.stat().st_size
},indent=2))
