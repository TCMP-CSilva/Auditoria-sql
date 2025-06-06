import os
import sys

# Carpeta que contiene los archivos SQL a auditar
FOLDER_PATH = 'auditSQL'

def revisar_nolock(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        contenido = f.read().lower()
        if 'nolock' in contenido:
            print(f"❌ Se encontró NOLOCK en: {file_path}")
            return True
    return False

def main():
    hubo_error = False

    if not os.path.isdir(FOLDER_PATH):
        print(f"⚠️ La carpeta {FOLDER_PATH} no existe.")
        sys.exit(1)

    for root, _, files in os.walk(FOLDER_PATH):
        for file in files:
            if file.endswith('.sql'):
                full_path = os.path.join(root, file)
                if revisar_nolock(full_path):
                    hubo_error = True

    if hubo_error:
        print("🚨 Se encontraron usos indebidos de NOLOCK. Revisa el detalle arriba.")
        sys.exit(1)
    else:
        print("✅ Sin usos de NOLOCK detectados.")

if __name__ == '__main__':
    main()
