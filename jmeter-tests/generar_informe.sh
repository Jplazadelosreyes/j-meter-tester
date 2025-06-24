#!/bin/bash

# Define la ruta base donde se espera que estén los archivos de resultados dentro del contenedor.
# El usuario 'jmeter' tiene su HOME en /home/jmeter.
# Se asume que los resultados se guardarán en /home/jmeter/jmeter-results/ dentro del contenedor.
RESULTS_BASE_DIR="/home/jmeter/jmeter-results" # <--- RUTA FIJA Y ABSOLUTA DENTRO DEL CONTENEDOR

# Define las rutas completas al archivo JTL y al directorio de salida.
JTL_FILE="${RESULTS_BASE_DIR}/Reporte.jtl"
OUTPUT_DIR="${RESULTS_BASE_DIR}/reporte_html"

# --- Comprobaciones iniciales ---

# Comprobar si JMeter está disponible en el PATH del contenedor.
if ! command -v jmeter &> /dev/null
then
    echo "Error: JMeter no se encontró. Esto no debería ocurrir si la imagen Docker se construyó correctamente."
    exit 1
fi

# Comprobar si el archivo JTL de resultados existe.
if [ ! -f "$JTL_FILE" ]; then
    echo "Error: El archivo JTL '$JTL_FILE' no se encontró."
    echo "Asegúrate de que 'Reporte.jtl' haya sido guardado en la carpeta 'jmeter-results' dentro del contenedor."
    echo "Ejemplo: /home/jmeter/jmeter-results/Reporte.jtl"
    exit 1
fi

# Crear el directorio de salida para el informe HTML si no existe.
# El usuario 'jmeter' debería tener permisos para escribir en su propio directorio home o volúmenes montados.
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creando directorio de salida: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    # No es necesario 'chown' si 'jmeter' es el usuario que ejecuta y es el dueño o tiene permisos.
    # Si aun así hay problemas de permisos, se podría revisar la configuración de permisos del volumen en el host.
fi

# --- Generación del informe HTML ---

echo "Generando el informe HTML de JMeter desde '$JTL_FILE'..."
echo "Los archivos HTML se guardarán en: $OUTPUT_DIR"

# Ejecuta el comando JMeter para generar el informe HTML.
# La opción -g especifica el archivo JTL de entrada.
# La opción -o especifica el directorio de salida para el informe HTML.
# Se añade la opción -f (o --force) para sobrescribir el directorio de salida si no está vacío.
# JMeter se ejecuta como el usuario 'jmeter' (configurado en el Dockerfile).
jmeter -g "$JTL_FILE" -o "$OUTPUT_DIR" -f # <--- AÑADIDO: -f (o --force) para sobrescribir

# Comprobar el código de salida de JMeter para verificar el éxito.
if [ $? -eq 0 ]; then
    echo "¡Informe HTML generado con éxito en '$OUTPUT_DIR' dentro del contenedor!"
    echo "Para acceder al reporte, copia la carpeta a tu máquina local con:"
    echo "  docker cp <nombre_o_ID_contenedor>:${OUTPUT_DIR} /ruta/local/para/guardar_el_reporte"
else
    echo "Error: Falló la generación del informe HTML de JMeter."
    exit 1
fi
