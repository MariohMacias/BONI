"""
BONI Tool: Memoria Persistente
Permite a BONI guardar y recuperar información entre conversaciones.
"""
import json, os
from datetime import datetime
from typing import Optional, List

MEMORIA_DIR = os.path.expanduser("~/.boni")
os.makedirs(MEMORIA_DIR, exist_ok=True)
MEMORIA_FILE = os.path.join(MEMORIA_DIR, "memoria.json")

class Tools:
    class Valves:
        pass

    def __init__(self):
        pass

    def _cargar_memoria(self) -> dict:
        if not os.path.exists(MEMORIA_FILE):
            return {"notas": [], "hechos": {}, "tareas": []}
        try:
            with open(MEMORIA_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {"notas": [], "hechos": {}, "tareas": []}

    def _guardar_memoria(self, data: dict) -> bool:
        try:
            with open(MEMORIA_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            return True
        except Exception:
            return False

    def recordar_hecho(self, clave: str, valor: str) -> str:
        """Guarda un hecho clave-valor que BONI debe recordar siempre. Ejemplos: recordar_hecho('nombre_usuario', 'Mario'). Args: clave: Identificador único del hecho, valor: Valor a recordar"""
        mem = self._cargar_memoria()
        mem["hechos"][clave] = {"valor": valor, "actualizado": datetime.now().isoformat()}
        self._guardar_memoria(mem)
        return json.dumps({"guardado": True, "clave": clave, "valor": valor})

    def obtener_hecho(self, clave: str) -> str:
        """Recupera un hecho guardado por su clave. Args: clave: La clave a buscar"""
        mem = self._cargar_memoria()
        if clave in mem["hechos"]:
            return json.dumps(mem["hechos"][clave])
        return json.dumps({"error": f"No hay hecho con clave '{clave}'"})

    def guardar_nota(self, titulo: str, contenido: str, etiquetas: Optional[str] = None) -> str:
        """Guarda una nota con título y contenido. Args: titulo: Título de la nota, contenido: Contenido completo, etiquetas: Etiquetas separadas por coma"""
        mem = self._cargar_memoria()
        nota = {"id": len(mem["notas"]) + 1, "titulo": titulo, "contenido": contenido,
                "etiquetas": [e.strip() for e in etiquetas.split(",")] if etiquetas else [],
                "creada": datetime.now().isoformat()}
        mem["notas"].append(nota)
        self._guardar_memoria(mem)
        return json.dumps({"guardada": True, "id": nota["id"], "titulo": titulo})

    def buscar_notas(self, termino: str) -> str:
        """Busca notas por título o contenido. Args: termino: Texto a buscar"""
        mem = self._cargar_memoria()
        termino_lower = termino.lower()
        resultados = []
        for nota in mem["notas"]:
            if termino_lower in nota["titulo"].lower() or termino_lower in nota["contenido"].lower():
                resultados.append({"id": nota["id"], "titulo": nota["titulo"],
                    "preview": nota["contenido"][:150] + "..." if len(nota["contenido"]) > 150 else nota["contenido"]})
        return json.dumps({"resultados": resultados, "total": len(resultados)})

    def listar_hechos(self) -> str:
        """Lista todos los hechos guardados en memoria"""
        mem = self._cargar_memoria()
        return json.dumps({"hechos": list(mem["hechos"].keys()), "total": len(mem["hechos"])})

    def agregar_tarea(self, descripcion: str, prioridad: str = "normal") -> str:
        """Agrega una tarea pendiente. Args: descripcion: Qué hay que hacer, prioridad: alta/normal/baja"""
        mem = self._cargar_memoria()
        tarea = {"id": len(mem["tareas"]) + 1, "descripcion": descripcion,
                 "prioridad": prioridad, "estado": "pendiente", "creada": datetime.now().isoformat()}
        mem["tareas"].append(tarea)
        self._guardar_memoria(mem)
        return json.dumps({"agregada": True, "id": tarea["id"]})

    def ver_tareas(self, solo_pendientes: bool = True) -> str:
        """Muestra las tareas guardadas. Args: solo_pendientes: True solo muestra pendientes"""
        mem = self._cargar_memoria()
        tareas = mem["tareas"]
        if solo_pendientes:
            tareas = [t for t in tareas if t["estado"] == "pendiente"]
        return json.dumps({"tareas": tareas, "total": len(tareas)})

    def completar_tarea(self, id_tarea: int) -> str:
        """Marca una tarea como completada. Args: id_tarea: ID numérico de la tarea"""
        mem = self._cargar_memoria()
        for tarea in mem["tareas"]:
            if tarea["id"] == id_tarea:
                tarea["estado"] = "completada"
                tarea["completada"] = datetime.now().isoformat()
                self._guardar_memoria(mem)
                return json.dumps({"completada": True, "tarea": tarea["descripcion"]})
        return json.dumps({"error": f"No se encontró tarea con ID {id_tarea}"})
