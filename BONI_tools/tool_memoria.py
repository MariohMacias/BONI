"""
BONI Tool: Memoria Persistente
Permite a BONI guardar y recuperar información entre conversaciones.
Usa un archivo JSON local — todo se queda en tu computadora.

Instalación: Settings > Tools > (+) Add Tool
"""

import json
import os
from datetime import datetime
from typing import Optional, List

# ── Configuración ────────────────────────────────────────────────
MEMORIA_DIR = os.path.expanduser("~/.boni")
os.makedirs(MEMORIA_DIR, exist_ok=True)
MEMORIA_FILE = os.path.join(MEMORIA_DIR, "memoria.json")


def _cargar_memoria() -> dict:
    """Carga la memoria desde disco."""
    if not os.path.exists(MEMORIA_FILE):
        return {"notas": [], "hechos": {}, "tareas": []}
    try:
        with open(MEMORIA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {"notas": [], "hechos": {}, "tareas": []}


def _guardar_memoria(data: dict) -> bool:
    """Guarda la memoria en disco."""
    try:
        with open(MEMORIA_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return True
    except Exception:
        return False


def recordar_hecho(clave: str, valor: str) -> dict:
    """
    Guarda un hecho clave-valor que BONI debe recordar siempre.
    Útil para preferencias, datos del usuario, configuraciones.
    
    Ejemplos:
        recordar_hecho("nombre_usuario", "Mario")
        recordar_hecho("ciudad", "Monterrey")
        recordar_hecho("proyecto_actual", "competencias.html")
    
    Args:
        clave: Identificador único del hecho (sin espacios)
        valor: Valor a recordar
    """
    mem = _cargar_memoria()
    mem["hechos"][clave] = {
        "valor": valor,
        "actualizado": datetime.now().isoformat()
    }
    _guardar_memoria(mem)
    return {"guardado": True, "clave": clave, "valor": valor}


def obtener_hecho(clave: str) -> dict:
    """
    Recupera un hecho guardado.
    
    Args:
        clave: La clave a buscar
    """
    mem = _cargar_memoria()
    if clave in mem["hechos"]:
        return mem["hechos"][clave]
    return {"error": f"No hay ningún hecho guardado con la clave '{clave}'"}


def guardar_nota(titulo: str, contenido: str, etiquetas: Optional[List[str]] = None) -> dict:
    """
    Guarda una nota con título, contenido y etiquetas opcionales.
    
    Args:
        titulo: Título corto de la nota
        contenido: Contenido completo de la nota
        etiquetas: Lista de etiquetas para organizar (ej: ["trabajo", "código"])
    """
    mem = _cargar_memoria()
    nota = {
        "id": len(mem["notas"]) + 1,
        "titulo": titulo,
        "contenido": contenido,
        "etiquetas": etiquetas or [],
        "creada": datetime.now().isoformat()
    }
    mem["notas"].append(nota)
    _guardar_memoria(mem)
    return {"guardada": True, "id": nota["id"], "titulo": titulo}


def buscar_notas(termino: str) -> dict:
    """
    Busca notas por título, contenido o etiqueta.
    
    Args:
        termino: Texto a buscar
    """
    mem = _cargar_memoria()
    termino_lower = termino.lower()
    resultados = []
    
    for nota in mem["notas"]:
        if (termino_lower in nota["titulo"].lower() or
            termino_lower in nota["contenido"].lower() or
            any(termino_lower in e.lower() for e in nota["etiquetas"])):
            resultados.append({
                "id": nota["id"],
                "titulo": nota["titulo"],
                "preview": nota["contenido"][:150] + "..." if len(nota["contenido"]) > 150 else nota["contenido"],
                "etiquetas": nota["etiquetas"],
                "creada": nota["creada"]
            })
    
    return {"resultados": resultados, "total": len(resultados)}


def listar_hechos() -> dict:
    """
    Lista todos los hechos guardados en memoria.
    """
    mem = _cargar_memoria()
    return {"hechos": mem["hechos"], "total": len(mem["hechos"])}


def agregar_tarea(descripcion: str, prioridad: str = "normal") -> dict:
    """
    Agrega una tarea pendiente a la lista de BONI.
    
    Args:
        descripcion: Qué hay que hacer
        prioridad: "alta", "normal" o "baja"
    """
    mem = _cargar_memoria()
    tarea = {
        "id": len(mem["tareas"]) + 1,
        "descripcion": descripcion,
        "prioridad": prioridad,
        "estado": "pendiente",
        "creada": datetime.now().isoformat()
    }
    mem["tareas"].append(tarea)
    _guardar_memoria(mem)
    return {"agregada": True, "id": tarea["id"]}


def ver_tareas(solo_pendientes: bool = True) -> dict:
    """
    Muestra las tareas guardadas.
    
    Args:
        solo_pendientes: Si True, solo muestra tareas sin completar
    """
    mem = _cargar_memoria()
    tareas = mem["tareas"]
    if solo_pendientes:
        tareas = [t for t in tareas if t["estado"] == "pendiente"]
    return {"tareas": tareas, "total": len(tareas)}


def completar_tarea(id_tarea: int) -> dict:
    """
    Marca una tarea como completada.
    
    Args:
        id_tarea: El ID numérico de la tarea
    """
    mem = _cargar_memoria()
    for tarea in mem["tareas"]:
        if tarea["id"] == id_tarea:
            tarea["estado"] = "completada"
            tarea["completada"] = datetime.now().isoformat()
            _guardar_memoria(mem)
            return {"completada": True, "tarea": tarea["descripcion"]}
    return {"error": f"No se encontró tarea con ID {id_tarea}"}
