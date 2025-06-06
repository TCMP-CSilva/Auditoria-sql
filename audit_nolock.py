import os
import re
import sys

AUDIT_FOLDER = "auditSQL"
pattern = re.compile(r"\bwith\s*\(.*?\bNOLOCK\b.*?\)", re.IGNORECASE)

violations = {}

for root, _, files in os.walk(AUDIT_FOLDER):
    for file in files:
        if file.endswith(".sql"):
            filepath = os.path.join(root, file)
            with open(filepath, "r", encoding="utf-8") as f:
                for lineno, line in enumerate(f, start=1):
                    if "nolock" in line.lower() and pattern.search(line):
                        if filepath not in violations:
                            violations[filepath] = []
                        violations[filepath].append((lineno, line.strip()))

# Salida
if violations:
    print("❌ Se encontraron usos indebidos de NOLOCK:\n")
    for file, lines in violations.items():
        print(f"📄 Archivo: {file}")
        for lineno, content in lines:
            print(f"   🔸 Línea {lineno}: {content}")
        print("-" * 60)
    print(f"\n🚨 Total de archivos con NOLOCK: {len(violations)}")
    total = sum(len(v) for v in violations.values())
    print(f"🚨 Total de ocurrencias encontradas: {total}")
    sys.exit(1)
else:
    print("✅ No se encontraron usos indebidos de NOLOCK en los archivos auditados.")
    sys.exit(0)
