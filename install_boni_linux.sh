#!/bin/bash

# Script de Instalación para B.O.N.I. AI en Linux
# Este script guiará al usuario paso a paso para configurar y ejecutar el sistema B.O.N.I. AI.

# --- Colores para la salida de la consola ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[ÉXITO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Función para verificar si un comando existe ---
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# --- Función para pausar la ejecución ---
press_any_key() {
  log_info "Presiona cualquier tecla para continuar..."
  read -n 1 -s
}

# --- Bienvenida ---
clear
log_info "======================================================"
log_info "  Bienvenido al Instalador de B.O.N.I. AI para Linux  "
log_info "======================================================"
log_info "Este script te ayudará a instalar y configurar B.O.N.I. AI en tu sistema."
log_info "Asegúrate de tener conexión a internet."
press_any_key

# --- 1. Verificación de Prerrequisitos ---
log_info "\n--- 1. Verificando Prerrequisitos ---"

# 1.1. Node.js y npm
log_info "Verificando Node.js y npm..."
if ! command_exists node || ! command_exists npm; then
  log_warning "Node.js o npm no encontrados. Instalando Node.js y npm..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  if ! command_exists node || ! command_exists npm; then
    log_error "Fallo al instalar Node.js y npm. Por favor, instálalos manualmente y vuelve a ejecutar el script."
    exit 1
  fi
  log_success "Node.js y npm instalados correctamente."
else
  NODE_VERSION=$(node -v)
  log_info "Node.js y npm ya están instalados. Versión de Node.js: ${NODE_VERSION}"
fi
press_any_key

# 1.2. MongoDB
log_info "Verificando MongoDB..."
if ! command_exists mongod; then
  log_warning "MongoDB no encontrado. Instalando MongoDB..."
  # Importar la clave pública de GPG
  sudo apt-get install -y gnupg curl
  curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg
  # Crear el archivo de lista para MongoDB
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
  # Actualizar la lista de paquetes
  sudo apt-get update
  # Instalar MongoDB
  sudo apt-get install -y mongodb-org
  
  if ! command_exists mongod; then
    log_error "Fallo al instalar MongoDB. Por favor, instálalo manualmente y vuelve a ejecutar el script."
    exit 1
  fi
  log_success "MongoDB instalado correctamente."
  log_info "Iniciando el servicio de MongoDB..."
  sudo systemctl start mongod
  sudo systemctl enable mongod
  log_success "Servicio de MongoDB iniciado y habilitado para iniciar con el sistema."
else
  log_info "MongoDB ya está instalado. Versión de MongoDB: $(mongod --version | grep 'db version')"
  log_info "Verificando estado del servicio MongoDB..."
  if systemctl is-active --quiet mongod; then
    log_success "Servicio de MongoDB está activo y funcionando."
  else
    log_warning "Servicio de MongoDB no está activo. Intentando iniciarlo..."
    sudo systemctl start mongod
    sudo systemctl enable mongod
    if systemctl is-active --quiet mongod; then
      log_success "Servicio de MongoDB iniciado y habilitado."
    else
      log_error "Fallo al iniciar el servicio de MongoDB. Por favor, verifícalo manualmente."
      exit 1
    fi
  fi
fi
press_any_key

# 1.3. Git
log_info "Verificando Git..."
if ! command_exists git; then
  log_warning "Git no encontrado. Instalando Git..."
  sudo apt-get install -y git
  if ! command_exists git; then
    log_error "Fallo al instalar Git. Por favor, instálalo manualmente y vuelve a ejecutar el script."
    exit 1
  fi
  log_success "Git instalado correctamente."
else
  log_info "Git ya está instalado. Versión de Git: $(git --version)"
fi
press_any_key

# --- 2. Clonar el Repositorio de B.O.N.I. AI ---
log_info "\n--- 2. Clonando el Repositorio de B.O.N.I. AI ---"

REPO_URL="https://github.com/your-repo/boni-ai.git" # TODO: Reemplazar con la URL real del repositorio
INSTALL_DIR="$(pwd)/boni-ai"

if [ -d "$INSTALL_DIR" ]; then
  log_warning "El directorio '$INSTALL_DIR' ya existe. Saltando la clonación del repositorio."
  log_info "Si deseas una instalación limpia, elimina el directorio '$INSTALL_DIR' antes de ejecutar el script."
else
  log_info "Clonando el repositorio desde $REPO_URL en $INSTALL_DIR..."
  git clone "$REPO_URL" "$INSTALL_DIR"
  if [ $? -ne 0 ]; then
    log_error "Fallo al clonar el repositorio. Verifica la URL o tu conexión a internet."
    exit 1
  fi
  log_success "Repositorio clonado exitosamente."
fi
press_any_key

# --- 3. Configuración del Backend ---
log_info "\n--- 3. Configurando el Backend ---"
BACKEND_DIR="$INSTALL_DIR/boni-backend"

if [ ! -d "$BACKEND_DIR" ]; then
  log_error "Directorio del backend no encontrado: $BACKEND_DIR. Asegúrate de que el repositorio se clonó correctamente."
  exit 1
fi

cd "$BACKEND_DIR"

log_info "Instalando dependencias del backend..."
npm install
if [ $? -ne 0 ]; then
  log_error "Fallo al instalar las dependencias del backend. Por favor, revisa los errores."
  exit 1
fi
log_success "Dependencias del backend instaladas exitosamente."

log_info "Configurando variables de entorno del backend (.env)..."
if [ ! -f ".env" ]; then
  cp .env.example .env
  log_info "Se ha creado un archivo .env básico. Por favor, edítalo con tus claves API y configuraciones."
  log_info "Puedes editarlo con 'nano .env' o tu editor de texto preferido."
  log_info "Asegúrate de configurar MISTRAL_API_KEY y JWT_SECRET."
  press_any_key
else
  log_info "El archivo .env ya existe. Si necesitas modificarlo, hazlo manualmente."
fi

log_info "Ejecutando migraciones de base de datos (si aplica)..."
npm run migrate
if [ $? -ne 0 ]; then
  log_warning "Fallo al ejecutar las migraciones. Esto puede ser normal si no hay migraciones pendientes o si la base de datos ya está actualizada."
fi
log_success "Configuración del backend completada."
press_any_key

# --- 4. Configuración del Frontend (Panel de Administración) ---
log_info "\n--- 4. Configurando el Frontend (Panel de Administración) ---"
FRONTEND_DIR="$INSTALL_DIR/boni-admin-panel"

if [ ! -d "$FRONTEND_DIR" ]; then
  log_warning "Directorio del frontend no encontrado: $FRONTEND_DIR. Asumiendo que el frontend se manejará por separado o no es necesario para esta instalación."
  log_info "Si el frontend existe, asegúrate de que el repositorio lo incluya o clónalo manualmente."
  FRONTEND_EXISTS=false
else
  FRONTEND_EXISTS=true
  cd "$FRONTEND_DIR"
  log_info "Instalando dependencias del frontend..."
  npm install
  if [ $? -ne 0 ]; then
    log_error "Fallo al instalar las dependencias del frontend. Por favor, revisa los errores."
    exit 1
  fi
  log_success "Dependencias del frontend instaladas exitosamente."
  log_success "Configuración del frontend completada."
fi
press_any_key

# --- 5. Inicio del Sistema ---
log_info "\n--- 5. Iniciando el Sistema B.O.N.I. AI ---"

log_info "Iniciando el backend de B.O.N.I. AI..."
cd "$BACKEND_DIR"
# Usamos 'nohup' y '&' para que el servidor se ejecute en segundo plano
nohup npm start > boni_backend.log 2>&1 &
BACKEND_PID=$!
log_info "Backend iniciado en segundo plano. PID: $BACKEND_PID. Logs en boni_backend.log"

if [ "$FRONTEND_EXISTS" = true ]; then
  log_info "Iniciando el frontend (Panel de Administración) de B.O.N.I. AI..."
  cd "$FRONTEND_DIR"
  nohup npm run dev -- --host > boni_frontend.log 2>&1 &
  FRONTEND_PID=$!
  log_info "Frontend iniciado en segundo plano. PID: $FRONTEND_PID. Logs en boni_frontend.log"
else
  log_warning "Frontend no encontrado, no se iniciará."
fi

log_info "Esperando unos segundos para que los servicios se inicien completamente..."
sleep 10

log_success "¡Instalación y configuración de B.O.N.I. AI completadas!"
log_info "\n--- Información Importante ---"
log_info "Backend de B.O.N.I. AI debería estar accesible en: ${BLUE}http://localhost:3001${NC}"
if [ "$FRONTEND_EXISTS" = true ]; then
  log_info "Panel de Administración de B.O.N.I. AI debería estar accesible en: ${BLUE}http://localhost:5173${NC}"
else
  log_warning "Recuerda que el frontend no se inició. Si lo necesitas, instálalo y ejecútalo manualmente."
fi
log_info "Puedes verificar los logs en boni_backend.log y boni_frontend.log (si aplica) en sus respectivos directorios."
log_info "Para detener los servicios, puedes usar 'kill $BACKEND_PID' y 'kill $FRONTEND_PID'."
log_info "¡Disfruta de B.O.N.I. AI!"

exit 0


