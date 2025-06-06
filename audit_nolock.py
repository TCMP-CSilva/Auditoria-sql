import os
import re
import sys

# Carpeta donde están los archivos a auditar
audit_folder = "auditSQL"

# Expresión regular para detectar variantes NOLOCK con o sin WITH, espacios, mayúsculas, minúsculas
# Captura también combinaciones con READUNCOMMITTED
nolock_pattern = re.compile(
    r"""
    # Opcional WITH, seguido de espacios opcionales
    (WITH\s*)?
    # Paréntesis que contienen nolock (con posibles espacios y opciones)
    \(\s*NOLOCK\s*(,\s*READUNCOMMITTED\s*)?\)
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Expresión para detectar "(NOLOCK)" sin WITH
nolock_paren_only_pattern = re.compile(
    r"""
    # Paréntesis con NOLOCK, posible espacio antes y después
    \(\s*NOLOCK\s*(,\s*READUNCOMMITTED\s*)?\)
    """,
    re.IGNORECASE | re.VERBOSE,
)

# Ignorar tablas temporales que empiezan con # o ##
ignore_temp_tables_pattern = re.compile(r"FROM\s+[#@]{1,2}[\w\d_]+", re.IGNORECASE)

def audit_file(filepath):
    findings = []
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, start=1):
        # Ignorar líneas comentadas
        if line.strip().startswith("--"):
            continue

        # Ignorar tablas temporales o variables (ejemplo: FROM #Temp, FROM @Tabla)
        if ignore_temp_tables_pattern.search(line):
            continue

        # Buscar NOLOCK en la línea (con o sin WITH)
        if nolock_pattern.search(line) or nolock_paren_only_pattern.search(line):
            findings.append(f"   🔸 Línea {idx}: {line.strip()}")

    return findings

def main():
    total_issues = 0
    files_with_issues = []

    for root, _, files in os.walk(audit_folder):
        for file in files:
            if file.endswith(".sql"):
                filepath = os.path.join(root, file)
                issues = audit_file(filepath)
                if issues:
                    files_with_issues.append(filepath)
                    print(f"Archivo: {filepath}")
                    for issue in issues:
                        print(issue)
                    print()
                    total_issues += len(issues)

    if total_issues > 0:
        print(f"🚨 Se encontraron usos indebidos de NOLOCK. Revisa el detalle arriba.")
        print(f"❌ Se encontraron NOLOCK en: {', '.join(files_with_issues)}")
        sys.exit(1)
    else:
        print("✅ No se encontraron usos indebidos de NOLOCK.")

if __name__ == "__main__":
    main()
