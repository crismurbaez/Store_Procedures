# Reglas del Proyecto - Store Procedures RBK4

## Regla Fundamental - Modificación de Código

### ⚠️ REGLA CRÍTICA: NO MODIFICAR CÓDIGO SIN SOLICITUD EXPLÍCITA

**NUNCA realizar cambios en el código salvo que se solicite en forma explícita.**

### Aplicación de la Regla

Esta regla se aplica a **TODOS los chats** de este proyecto y significa que:

#### ✅ ACCIONES PERMITIDAS (Solo cuando se solicite explícitamente)
- Modificar archivos existentes
- Crear nuevos archivos
- Eliminar archivos
- Cambiar tipos de datos
- Descomentar líneas de código
- Aplicar cualquier cambio al código fuente

#### ✅ ACCIONES SIEMPRE PERMITIDAS (Sin solicitud explícita)
- Analizar errores y explicar las causas
- Sugerir soluciones y explicar cómo implementarlas
- Responder preguntas sobre el código existente
- Explicar conceptos técnicos
- Leer y examinar archivos
- Buscar en el código base
- Explicar patrones y estructuras

#### ❌ ACCIONES PROHIBIDAS (Sin solicitud explícita)
- Modificar archivos sin solicitud directa
- Aplicar "mejoras" no solicitadas
- Cambiar tipos de datos sin instrucción explícita
- Descomentar líneas sin solicitud
- Crear archivos sin solicitud
- Eliminar archivos sin solicitud
- Realizar cualquier cambio al código fuente

### Ejemplos de Solicitudes Válidas

✅ **"Arregla el error en sp_centroscosto_modificar.sql"**
✅ **"Descomenta la línea 4 del DROP FUNCTION"**
✅ **"Cambia los tipos de datos de character varying a varchar"**
✅ **"Crea un nuevo stored procedure para..."**

### Ejemplos de lo que NO haré sin solicitud

❌ **Modificar automáticamente archivos con errores**
❌ **Aplicar "mejoras" que detecte en el código**
❌ **Cambiar tipos de datos para "corregir" errores**
❌ **Descomentar líneas que vea comentadas**

### Alcance del Proyecto

Esta regla se aplica a:
- Todos los stored procedures (Nivel 1, 2, 3, 4, 5)
- Archivos de esquema de base de datos
- Archivos de documentación
- Cualquier archivo del proyecto

### Fecha de Aplicación

**Aplicable desde:** Diciembre 2024
**Proyecto:** Store Procedures RBK4 - Niveles Jerárquicos
**Versión:** 1.0

---

**IMPORTANTE:** Esta regla tiene prioridad sobre cualquier otra instrucción o patrón detectado en el código. Solo se realizarán cambios cuando se solicite explícitamente.
