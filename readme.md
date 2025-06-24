[![Build and Test JMeter GUI](https://github.com/Jplazadelosreyes/j-meter-tester/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Jplazadelosreyes/j-meter-tester/actions/workflows/test.yml)
# JMeter GUI con VNC en Docker

Este repositorio proporciona un entorno Dockerizado completo para ejecutar Apache JMeter con una interfaz gráfica de usuario (GUI) a la que se puede acceder vía VNC. Además, incluye scripts para automatizar la generación de informes HTML a partir de los resultados de tus pruebas.

## Tabla de Contenidos

- [Visión General](#visión-general)
- [Prerrequisitos](#prerrequisitos)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Archivos del Proyecto](#archivos-del-proyecto)
    - [Dockerfile](#dockerfile)
    - [docker-compose.yml](#docker-composeyml)
    - [start_jmeter_vnc.sh](#start_jmeter_vncsh)
    - [generar_informe.sh](#generar_informesh)
- [Configuración Inicial](#configuración-inicial)
- [Uso](#uso)
    - [1. Levantar el Entorno JMeter](#1-levantar-el-entorno-jmeter)
    - [2. Conectarse a JMeter vía VNC](#2-conectarse-a-jmeter-vía-vnc)
    - [3. Ejecutar Pruebas y Guardar Resultados](#3-ejecutar-pruebas-y-guardar-resultados)
    - [4. Generar el Informe HTML](#4-generar-el-informe-html)
    - [5. Acceder al Informe Generado](#5-acceder-al-informe-generado)
- [Limpieza](#limpieza)
- [Troubleshooting Común](#troubleshooting-común)

## Visión General

Este setup te permite:

- Ejecutar Apache JMeter en un contenedor Docker con una GUI completa.
- Acceder a la GUI de JMeter remotamente usando cualquier cliente VNC.
- Montar directorios locales para compartir planes de prueba (.jmx) y persistir resultados (.jtl) e informes HTML.
- Automatizar la generación de informes HTML a partir de tus archivos .jtl dentro del mismo contenedor.

## Prerrequisitos

Antes de comenzar, asegúrate de tener instalado en tu máquina local:

- **Docker Desktop** (incluye Docker Engine y Docker Compose) o **Docker Engine** y **Docker Compose CLI** (para Linux).
- Un **cliente VNC** (por ejemplo, RealVNC Viewer, TightVNC Viewer, Remmina).

## Estructura del Proyecto

Tu proyecto debe tener la siguiente estructura de directorios en tu máquina local:

```
.
├── Dockerfile
├── docker-compose.yml
├── jmeter-results/
│   └── (Aquí se guardarán tus archivos .jtl y los informes HTML generados)
├── jmeter-tests/
│   ├── generar_informe.sh
│   └── (Aquí irán tus archivos .jmx de planes de prueba, por ejemplo, Thread Group.jmx)
└── start_jmeter_vnc.sh
```

## Archivos del Proyecto

A continuación, se detalla el contenido de cada archivo clave. Debes crear estos archivos con el contenido exacto proporcionado si no los tienes ya en tu proyecto.

### Dockerfile

Este archivo construye la imagen Docker que contiene JMeter, el entorno VNC y todas las dependencias necesarias.

```dockerfile
# Usa una imagen base de OpenJDK 11 con JRE, ideal para JMeter.
FROM openjdk:11-jre-slim

# Instala paquetes necesarios de forma eficiente.
# Incluye 'unzip' para JMeter.
# Componentes para VNC y GUI (xterm, xfce4, tigervnc, etc.).
# 'libxtst6' para resolver el error 'libXtst.so.6: cannot open shared object file'.
# 'libnss-resolve' para asegurar la resolución de nombres de usuario.
# 'locales' para un entorno X11 estable.
# 'sudo' para permisos elevados si son necesarios (aunque se minimiza su uso).
# 'wget' para descargar JMeter.
# 'xauth' y 'dbus-x11' son cruciales para el entorno gráfico.
# Se añade 'bash' para la ejecución de scripts.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        unzip \
        xterm \
        xfce4 \
        xfce4-terminal \
        tigervnc-standalone-server \
        tigervnc-common \
        dbus-x11 \
        sudo \
        wget \
        libnss-resolve \
        libxtst6 \
        locales \
        xauth \
        bash && \
    rm -rf /var/lib/apt/lists/*

# Configuración de locales para un entorno X11 estable.
# Es buena práctica generarlos y luego establecer las variables de entorno.
RUN localedef -i en_US -c -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Definición de la versión de JMeter.
ARG JMETER_VERSION=5.6.3
ENV JMETER_HOME /opt/apache-jmeter-${JMETER_VERSION}
ENV PATH ${JMETER_HOME}/bin:${PATH}

# Descarga Apache JMeter desde la URL oficial, lo extrae y limpia el archivo temporal.
# Usa 'wget -q' para descarga silenciosa y 'unzip -q' para extracción silenciosa.
RUN wget -q https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.zip -O /tmp/apache-jmeter.zip && \
    unzip -q /tmp/apache-jmeter.zip -d /opt && \
    rm /tmp/apache-jmeter.zip

# Establece la contraseña por defecto para VNC.
ENV VNC_PW jmeterpassword

# Crea el usuario 'jmeter' y su directorio home.
# Las operaciones privilegiadas se realizan como 'root' antes de cambiar de usuario.
RUN useradd -m -s /bin/bash jmeter && \
    chown -R jmeter:jmeter /opt/apache-jmeter-${JMETER_VERSION}

# Copia el script de inicio 'start_jmeter_vnc.sh' desde el contexto de construcción (raíz del repo).
COPY start_jmeter_vnc.sh /usr/local/bin/

# NOTA: El script 'generar_informe.sh' NO se copia aquí directamente.
# Se accederá a él a través del volumen montado por docker-compose.

# Asegura que el script de inicio sea ejecutable.
RUN chmod +x /usr/local/bin/start_jmeter_vnc.sh

# Cambia al usuario 'jmeter' para las siguientes instrucciones y el comando final.
USER jmeter

# Establece el directorio de trabajo para el usuario 'jmeter'.
# Este es el directorio HOME del usuario 'jmeter' dentro del contenedor.
# Aquí es donde se espera que se guarden los resultados de JMeter.
WORKDIR /home/jmeter

# Puerto por defecto para VNC (5901 es el X display 1).
EXPOSE 5901

# Comando por defecto al iniciar el contenedor. Inicia el servidor VNC y JMeter.
CMD ["/usr/local/bin/start_jmeter_vnc.sh"]
```

### docker-compose.yml

Define el servicio Docker para tu entorno JMeter, gestionando puertos y volúmenes para la persistencia de datos.

```yaml
# Versión de la sintaxis de Docker Compose. Se recomienda la más reciente para nuevas configuraciones.
version: '3.8'

# Define los servicios que componen tu aplicación.
services:
  # Nombre del servicio para tu contenedor JMeter con interfaz gráfica.
  jmeter-gui:
    # Especifica que la imagen se construirá a partir del Dockerfile en el directorio actual.
    build: .

    # Nombre asignado al contenedor para facilitar su identificación.
    container_name: jmeter_gui

    # Mapeo de puertos entre el host y el contenedor.
    # El puerto 5901 del host se mapea al puerto 5901 del contenedor (VNC).
    ports:
      - "5901:5901"

    # Mapeo de volúmenes para persistencia y acceso a archivos.
    # Esto es crucial para que el contenedor pueda leer tus planes de prueba y guardar/leer tus resultados.
    volumes:
      # Monta la carpeta local 'jmeter-results' al directorio de resultados dentro del contenedor.
      # Asegura que los resultados generados o cargados en JMeter sean accesibles en el host.
      - ./jmeter-results:/home/jmeter/jmeter-results

      # Monta la carpeta local 'jmeter-tests' (donde tienes tus .jmx y el script generar_informe.sh)
      # al directorio /home/jmeter/jmeter-tests dentro del contenedor.
      - ./jmeter-tests:/home/jmeter/jmeter-tests
    
    # Restarta el contenedor si se detiene, a menos que se detenga manualmente.
    restart: "no"

    # El CMD del Dockerfile ya inicia el servidor VNC.
```

### start_jmeter_vnc.sh

Este script se ejecuta al iniciar el contenedor. Configura el servidor VNC, el entorno gráfico XFCE4 y lanza JMeter. Debes crear este archivo en la raíz de tu proyecto.

```bash
#!/bin/bash

# Ensure the VNC password directory exists and set the password
mkdir -p "$HOME"/.vnc
echo "$VNC_PW" | vncpasswd -f > "$HOME"/.vnc/passwd
chmod 600 "$HOME"/.vnc/passwd

# Create the xstartup script for XFCE4
# This script will be executed by the VNC server when it starts.
cat << 'EOF_INNER_XSTARTUP' > "$HOME"/.vnc/xstartup
#!/bin/bash

# Source profile for environmental variables like XDG_RUNTIME_DIR
# if you were using systemd, this would be auto-managed.
# For Docker slim images, often this is missing.
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# Ensure D-Bus is running for XFCE4
# This is crucial for many GUI applications and desktop environments
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval "$(dbus-launch --sh-syntax)"
fi

# Set a trap to ensure dbus-daemon exits when xfce4-session exits
trap "kill \$DBUS_SESSION_BUS_PID" EXIT

# Unset SESSION_MANAGER to let xfce4-session manage it
unset SESSION_MANAGER

# Disable screen blanking and power management
xset -dpms
xset s off

# Export the display variable
export DISPLAY=:1

# Start the XFCE4 session. 'exec' replaces the current shell process.
exec xfce4-session
EOF_INNER_XSTARTUP
chmod +x "$HOME"/.vnc/xstartup

# Start the VNC server in the background.
# The VNC server will execute the xstartup script for the graphical environment.
vncserver :1 -geometry 1280x800 -depth 24 -localhost no

# Give the VNC server and XFCE4 session ample time to initialize.
# This is a critical sleep, as JMeter needs the X server fully ready.
echo "Waiting for VNC and XFCE4 to fully initialize (30 seconds)..."
sleep 30 # Increased to 30 seconds for robustness

# Now launch JMeter. It will connect to the X server started by VNC.
echo "Launching JMeter..."
DISPLAY=:1 jmeter &

# Keep the container running
echo "JMeter started. Keeping container alive."
tail -f /dev/null
```

### generar_informe.sh

Este script se utiliza para generar informes HTML de JMeter a partir de un archivo .jtl existente. Debes crear este archivo dentro de la carpeta `jmeter-tests/` (es decir, `./jmeter-tests/generar_informe.sh`).

```bash
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
```

## Configuración Inicial

1. **Clona este repositorio** en tu máquina local:
   ```bash
   git clone https://github.com/tu_usuario/tu_repositorio.git
   cd tu_repositorio # Navega al directorio raíz del proyecto
   ```

2. **Crea los directorios necesarios**:
   Asegúrate de que existan las carpetas `jmeter-results/` y `jmeter-tests/` en la raíz de tu proyecto.
   ```bash
   mkdir -p jmeter-results
   mkdir -p jmeter-tests
   ```

3. **Crea los archivos de script**:
    - Crea el archivo `start_jmeter_vnc.sh` en el directorio raíz de tu proyecto y pega el contenido proporcionado arriba.
    - Crea el archivo `generar_informe.sh` dentro de la carpeta `jmeter-tests/` (es decir, `./jmeter-tests/generar_informe.sh`) y pega el contenido proporcionado arriba.
    - Asegúrate de que tus planes de prueba (.jmx) estén dentro de la carpeta `jmeter-tests/`.

## Uso

### 1. Levantar el Entorno JMeter

Desde el directorio raíz de tu proyecto (donde está `docker-compose.yml`), ejecuta:

```bash
docker-compose up -d --build --force-recreate
```

- `up`: Inicia el servicio `jmeter-gui`.
- `-d`: Ejecuta el contenedor en segundo plano (detached mode).
- `--build`: Fuerza la construcción (o reconstrucción) de la imagen Docker. ¡Esto es crucial para que cualquier cambio en el Dockerfile o los scripts se aplique!
- `--force-recreate`: Fuerza la recreación del contenedor, incluso si uno con el mismo nombre ya existe. Esto ayuda a evitar conflictos.

### 2. Conectarse a JMeter vía VNC

Una vez que el contenedor esté en ejecución (tardará un minuto en inicializarse):

1. Abre tu cliente VNC preferido.
2. Conéctate a la dirección: `localhost:5901`
3. Cuando se te pida, ingresa la contraseña: `jmeterpassword`
4. Verás la interfaz gráfica de JMeter lista para usar.

### 3. Ejecutar Pruebas y Guardar Resultados

Dentro de la GUI de JMeter:

1. **Abre tu plan de pruebas**: Navega a `File > Open` y busca tus archivos .jmx en la ruta `/home/jmeter/jmeter-tests/`.
2. **Ejecuta tus pruebas**.
3. **Guarda tus resultados**: Añade un elemento "Listener" como "View Results Tree" o "Simple Data Writer" a tu plan de pruebas. Asegúrate de guardar los resultados (.jtl) en la carpeta `/home/jmeter/jmeter-results/Reporte.jtl`.

> **Importante**: Es fundamental que el archivo .jtl se guarde en `/home/jmeter/jmeter-results/Reporte.jtl` dentro del contenedor para que el script de generación de informes pueda encontrarlo.

### 4. Generar el Informe HTML

Una vez que hayas finalizado tus pruebas y guardado el archivo `Reporte.jtl`, puedes generar un informe HTML profesional.

Abre una nueva terminal en tu máquina local (no dentro del VNC) y ejecuta:

```bash
docker exec jmeter_gui bash /home/jmeter/jmeter-tests/generar_informe.sh
```

Este comando ejecutará el script `generar_informe.sh` dentro de tu contenedor `jmeter_gui`. Verás la salida del proceso de generación del informe directamente en tu terminal.

### 5. Acceder al Informe Generado

Gracias a la configuración de volúmenes en `docker-compose.yml`, los informes HTML se guardarán automáticamente en tu máquina local.

Los archivos HTML se encontrarán en: `./jmeter-results/reporte_html/` en el directorio raíz de tu proyecto local.

Abre el archivo `index.html` dentro de esa carpeta con tu navegador web favorito:

```bash
# En macOS
open jmeter-results/reporte_html/index.html

# En Linux
xdg-open jmeter-results/reporte_html/index.html

# En Windows (usando Git Bash o WSL)
start jmeter-results/reporte_html/index.html
```

## Limpieza

Cuando hayas terminado de usar el entorno JMeter, puedes detener y eliminar los contenedores y la red creada por Docker Compose:

```bash
docker-compose down
```

> **Nota**: Esto no eliminará tus archivos .jtl ni los informes HTML, ya que están persistidos en tu carpeta local `jmeter-results/`.

## Troubleshooting Común

### `bash: /home/jmeter/jmeter-tests/generar_informe.sh: No such file or directory`

- Asegúrate de haber ejecutado `docker-compose up -d --build --force-recreate`.
- Verifica que el archivo `generar_informe.sh` esté realmente en `./jmeter-tests/` en tu máquina local.
- Verifica que el `docker-compose.yml` tenga el volumen `- ./jmeter-tests:/home/jmeter/jmeter-tests` correctamente definido.

### `Error: JMeter no se encontró...`

- Esto indica que JMeter no está en el PATH del contenedor. Asegúrate de haber ejecutado `docker-compose up -d --build --force-recreate` para reconstruir la imagen y que la instalación de JMeter en el Dockerfile fue exitosa.
- Puedes verificar manualmente entrando al contenedor: `docker exec -it jmeter_gui bash` y luego `jmeter -v`.

### `File 'Reporte.jtl' does not contain the field names header...`

- Esta es una advertencia. Significa que el archivo .jtl no tiene la línea de encabezado. Asegúrate de configurar JMeter para guardar los resultados con el encabezado (generalmente una opción en el "Simple Data Writer" o "View Results Tree" listener).
