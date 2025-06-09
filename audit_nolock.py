import re
import sys

# Patrón para detectar hint NOLOCK
nolock_pattern = re.compile(
    r"(WITH\s*)?\(\s*NOLOCK\s*(,\s*READUNCOMMITTED\s*)?\)", re.IGNORECASE
)

# Patrón para detectar tablas temporales o variables y excluirlas
ignore_table_pattern = re.compile(r"^[#@]", re.IGNORECASE)

# Patrón para capturar tablas en FROM o JOIN con posible alias
table_pattern = re.compile(
    r"\b(FROM|JOIN)\s+([\[\]\w\d_.]+)(?:\s+(\w+))?", re.IGNORECASE
)

def has_nolock_after(line, start_pos):
    # Busca si desde start_pos en adelante aparece hint NOLOCK
    segment = line[start_pos:]
    return bool(nolock_pattern.search(segment))

def audit_file(filepath):
    findings = []
    with open(filepath, encoding="utf-8") as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, start=1):
        line_strip = line.strip()

        # Ignorar comentarios
        if line_strip.startswith("--"):
            continue

        # Buscar tablas en FROM o JOIN
        for match in table_pattern.finditer(line):
            clause_type = match.group(1).upper()
            table_name = match.group(2)
            alias = match.group(3)

            # Ignorar tablas temporales o variables
            if ignore_table_pattern.match(table_name):
                continue

            # Posición donde termina el nombre de la tabla para buscar hint NOLOCK
            pos_end = match.end(2)

            # Verificar si hint NOLOCK está después del nombre de la tabla en la misma línea
            if has_nolock_after(line, pos_end):
                continue  # Correcto, tiene NOLOCK

            # Si no está en la misma línea, también se podría verificar la siguiente línea
            # pero normalmente hint NOLOCK va en la misma línea que la tabla
            # Por si acaso, mirar siguiente línea (si existe)
            if idx < len(lines):
                next_line = lines[idx].strip()
                if nolock_pattern.search(next_line):
                    continue

            # Si llegamos aquí, NOLOCK no está
            findings.append(
                f"Línea {idx}: Falta hint WITH (NOLOCK) en {clause_type} tabla '{table_name}'"
            )

    return findings

def main():
    if len(sys.argv) < 2:
        print("Uso: python audit_nolock.py archivo.sql")
        sys.exit(1)

    filepath = sys.argv[1]
    issues = audit_file(filepath)

    if issues:
        print(f"{filepath}: ❌ Se encontraron {len(issues)} error(es):\n")
        for issue in issues:
            print(issue)
        sys.exit(1)
    else:
        print("✅ No se encontraron usos indebidos de NOLOCK.")

if __name__ == "__main__":
    main()
