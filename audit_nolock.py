import re
import sys

def tiene_nolock(linea):
    variantes = [
        r'\bwith\s*\(\s*nolock\s*(?:,\s*\w+\s*)*\)',
        r'\(\s*nolock\s*(?:,\s*\w+\s*)*\)'
    ]
    for variante in variantes:
        if re.search(variante, linea, flags=re.IGNORECASE):
            return True
    return False

def es_tabla_temporal_ou_variable(linea):
    return re.search(r'\b(from|join)\s+[#@]', linea, flags=re.IGNORECASE) is not None

def extraer_tablas(linea):
    return re.findall(r'\b(from|join)\s+([\w\.#@]+)', linea, flags=re.IGNORECASE)

def analizar_sql(ruta_archivo):
    errores = []
    with open(ruta_archivo, 'r', encoding='utf-8') as archivo:
        lineas = archivo.readlines()

    for i, linea in enumerate(lineas, 1):
        if es_tabla_temporal_ou_variable(linea):
            continue

        tablas = extraer_tablas(linea)
        if tablas and not tiene_nolock(linea):
            errores.append((i, linea.strip()))
    return errores

def main():
    if len(sys.argv) != 2:
        print("Uso: python audit_nolock.py archivo.sql")
        sys.exit(1)

    ruta = sys.argv[1]
    errores = analizar_sql(ruta)

    if errores:
        print(f"{ruta}: ❌ Se encontraron {len(errores)} error(es):\n")
        for linea_num, contenido in errores:
            print(f"Línea {linea_num}: \"{contenido}\"  →  Falta hint WITH (NOLOCK).")
    else:
        print(f"{ruta}: ✅ No se detectaron faltantes de WITH (NOLOCK).")

if __name__ == '__main__':
    main()
