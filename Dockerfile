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
    xauth && \
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

# Copia el script de inicio 'start_jmeter_vnc.sh' desde el contexto de construcción.
# Este método es más robusto y menos propenso a errores de parsing de heredocs.
COPY start_jmeter_vnc.sh /usr/local/bin/

# Asegura que el script de inicio sea ejecutable.
RUN chmod +x /usr/local/bin/start_jmeter_vnc.sh

# Cambia al usuario 'jmeter' para las siguientes instrucciones y el comando final.
USER jmeter

# Establece el directorio de trabajo para el usuario 'jmeter'.
WORKDIR /home/jmeter

# Puerto por defecto para VNC (5901 es el X display 1).
EXPOSE 5901

# Comando por defecto al iniciar el contenedor. Inicia el servidor VNC y JMeter.
CMD ["/usr/local/bin/start_jmeter_vnc.sh"]