p# Solución: Inconsistencia entre Niveles Históricos y Niveles Actuales

## 📋 Resumen Ejecutivo

**Problema**: Los stored procedures de Gestor de Personas mezclaban niveles históricos del documento con niveles actuales del empleado, causando inconsistencias graves en la visualización de documentos.

**Solución**: Estandarización de todos los SPs para usar exclusivamente niveles históricos del documento (`DOC.*`).

**Fecha**: 15 de Octubre, 2025  
**Autor**: Emanuel Cuello  
**Módulo afectado**: Gestor de Personas

---

## 🔍 Problema Identificado

### Descripción del Problema

Los stored procedures del módulo Gestor de Personas presentaban una inconsistencia crítica en la forma de verificar permisos y construir JOINs:

-   **Algunos componentes** verificaban permisos contra la **ubicación actual del empleado** (tabla `empleados`)
-   **Otros componentes** verificaban permisos contra los **niveles históricos del documento** (tabla `g_documentosinfo`)

Esta mezcla causaba que un empleado apareciera en la búsqueda inicial pero sus documentos no se mostraran en el listado detallado.

### Escenario Real del Bug

**Situación:**

1. Un empleado trabajaba en **Empresa A, Depto X, Centro de Costo 100**
2. Se generaron 10 documentos para este empleado
3. Los documentos se guardaron en `g_documentosinfo` con estos niveles:
    ```
    lugarpagoid1 = "LP-A"
    departamentoid = "DEPTO-X"
    centrocostoid = "CC-100"
    ```
4. El empleado fue **trasladado** a **Empresa A, Depto Y, Centro de Costo 200**
5. La tabla `empleados` se actualizó:
    ```
    lugarpagoid = "LP-A"
    departamentoid = "DEPTO-Y"  ← Cambió
    centrocostoid = "CC-200"    ← Cambió
    ```

**Comportamiento incorrecto:**

-   ✅ `sp_gestorpersonas_xrut`: Mostraba al empleado porque verificaba permisos contra `EMPL.departamentoid = "DEPTO-Y"` (ubicación actual)
-   ❌ `sp_gestorpersonas_listaxtipodoc`: NO mostraba los documentos porque verificaba permisos contra `DOC.departamentoid = "DEPTO-X"` (ubicación histórica)

**Resultado**: El usuario veía al empleado en el listado pero al hacer clic no aparecían sus documentos. **Inconsistencia total**.

---

## 🏗️ Arquitectura de Datos

### Estructura de Tablas

#### Tabla `g_documentosinfo` - Niveles Históricos (Inmutables)

```sql
CREATE TABLE g_documentosinfo (
    documentoid INTEGER,
    empleadoid VARCHAR(10),
    empresaid VARCHAR(10),
    lugarpagoid1 VARCHAR(14),      -- ← Nivel histórico
    departamentoid VARCHAR(14),     -- ← Nivel histórico
    centrocostoid VARCHAR(14),      -- ← Nivel histórico
    divisionid VARCHAR(14),         -- ← Nivel histórico
    quintonivelid VARCHAR(14),      -- ← Nivel histórico
    fechadocumento DATE,
    -- ... otros campos
);
```

**Característica**: Los niveles se graban al momento de crear el documento y **NUNCA** cambian.

#### Tabla `empleados` - Niveles Actuales (Mutables)

```sql
CREATE TABLE empleados (
    empleadoid VARCHAR(10),
    RutEmpresa VARCHAR(10),
    lugarpagoid VARCHAR(14),        -- ← Nivel actual
    departamentoid VARCHAR(14),     -- ← Nivel actual
    centrocostoid VARCHAR(14),      -- ← Nivel actual
    divisionid VARCHAR(14),         -- ← Nivel actual
    quintonivelid VARCHAR(14),      -- ← Nivel actual
    -- ... otros campos
);
```

**Característica**: Los niveles se actualizan cuando el empleado es trasladado a otra área/departamento.

### Diferencias Clave

| Campo          | `g_documentosinfo`        | `empleados`          |
| -------------- | ------------------------- | -------------------- |
| Nivel 1        | `lugarpagoid1`            | `lugarpagoid`        |
| Nivel 2        | `departamentoid`          | `departamentoid`     |
| Nivel 3        | `centrocostoid`           | `centrocostoid`      |
| Nivel 4        | `divisionid`              | `divisionid`         |
| Nivel 5        | `quintonivelid`           | `quintonivelid`      |
| **Naturaleza** | **Histórico (inmutable)** | **Actual (mutable)** |

---

## ❌ Código Problemático (ANTES)

### SP: sp_gestorpersonas_listaxtipodoc (Versión Incorrecta)

```sql
-- PROBLEMA: Mezclaba fuentes de niveles
var_sql := '
    SELECT
        DOC.lugarpagoid1 AS lugarpagoid,  -- ✅ Desde DOC
        LP.nombrelugarpago,
        DOC.departamentoid,                -- ✅ Desde DOC
        DP.nombredepartamento,
        EMPL.centrocostoid,                -- ❌ Desde EMPL (nivel actual)
        CCO.nombrecentrocosto,
        EMPL.divisionid,                   -- ❌ Desde EMPL (nivel actual)
        DIV.nombredivision
    FROM g_documentosinfo AS DOC
    INNER JOIN empleados AS EMPL ...
    INNER JOIN centroscosto AS CCO
        ON CCO.centrocostoid = EMPL.centrocostoid  -- ❌ Usa nivel actual
       AND CCO.lugarpagoid = EMPL.lugarpagoid      -- ❌ Usa nivel actual
    INNER JOIN g_accesoxusuarioccosto ACC
        ON ACC.centrocostoid = EMPL.centrocostoid  -- ❌ Verifica permiso contra nivel actual
';
```

**Problema**: Si el empleado cambió de centro de costo, el JOIN falla porque:

-   `DOC.centrocostoid = "CC-100"` (histórico)
-   `EMPL.centrocostoid = "CC-200"` (actual)
-   El JOIN a `centroscosto` busca `CC-200` pero el documento tiene `CC-100`
-   **RESULTADO**: No encuentra el registro, documento no aparece

---

## ✅ Solución Implementada

### Principio Fundamental

> **REGLA DE ORO**: Los documentos son registros históricos inmutables. Siempre se deben usar los niveles del momento de su creación (`DOC.*`), no la ubicación actual del empleado (`EMPL.*`).

### Justificación

1. **Auditoría**: Un documento creado en el Depto X debe seguir mostrándose como del Depto X
2. **Permisos**: Solo usuarios con acceso al Depto X deben ver documentos creados en Depto X
3. **Trazabilidad**: Mantiene el contexto histórico correcto
4. **Consistencia**: Todos los SPs usan la misma fuente de datos

### Código Corregido

#### SP: sp_gestorpersonas_listaxtipodoc (Versión Correcta)

```sql
-- SOLUCIÓN: Todo desde niveles históricos del documento
var_sql := '
    SELECT
        DOC.lugarpagoid1 AS lugarpagoid,  -- ✅ Desde DOC
        LP.nombrelugarpago,
        DOC.departamentoid,                -- ✅ Desde DOC
        DP.nombredepartamento,
        DOC.centrocostoid,                 -- ✅ Desde DOC (nivel histórico)
        CCO.nombrecentrocosto,
        DOC.divisionid,                    -- ✅ Desde DOC (nivel histórico)
        DIV.nombredivision,
        DOC.quintonivelid,                 -- ✅ Desde DOC (nivel histórico)
        QN.nombrequintonivel
    FROM g_documentosinfo AS DOC
    INNER JOIN empleados AS EMPL ...
    -- JOINs dinámicos usando niveles históricos
    INNER JOIN lugarespago AS LP
        ON LP.lugarpagoid = DOC.lugarpagoid1      -- ✅ Nivel histórico
       AND LP.empresaid = DOC.empresaid
    INNER JOIN departamentos AS DP
        ON DP.departamentoid = DOC.departamentoid -- ✅ Nivel histórico
       AND DP.lugarpagoid = DOC.lugarpagoid1      -- ✅ Nivel histórico
       AND DP.empresaid = DOC.empresaid
    INNER JOIN centroscosto AS CCO
        ON CCO.centrocostoid = DOC.centrocostoid  -- ✅ Nivel histórico
       AND CCO.lugarpagoid = DOC.lugarpagoid1     -- ✅ Nivel histórico
       AND CCO.departamentoid = DOC.departamentoid-- ✅ Nivel histórico
       AND CCO.empresaid = DOC.empresaid
    -- Permisos usando niveles históricos
    INNER JOIN g_accesoxusuarioccosto ACC
        ON ACC.centrocostoid = DOC.centrocostoid  -- ✅ Verifica contra nivel histórico
       AND ACC.departamentoid = DOC.departamentoid-- ✅ Nivel histórico
       AND ACC.lugarpagoid = DOC.lugarpagoid1     -- ✅ Nivel histórico
       AND ACC.usuarioid = p_usuarioid
';
```

**Beneficio**: Ahora el documento se encuentra correctamente porque todos los JOINs usan `DOC.centrocostoid = "CC-100"` consistentemente.

---

## 📁 Archivos Modificados

### 1. sp_gestor/sp_gestorpersonas_listaxtipodoc.sql

**Cambios realizados:**

-   ✅ Campos SELECT niveles 3-5: Cambiados de `EMPL.*` a `DOC.*`
-   ✅ JOINs a tablas de niveles: Todos usan `DOC.lugarpagoid1`, `DOC.departamentoid`, `DOC.centrocostoid`, `DOC.divisionid`, `DOC.quintonivelid`
-   ✅ Permisos dinámicos: Verifican contra niveles del documento, no del empleado
-   ✅ Agregados comentarios "desde DOC" para claridad

**Líneas críticas modificadas:**

```sql
-- ANTES (líneas 76-93)
EMPL.centrocostoid, CCO.nombrecentrocosto
EMPL.divisionid, DIV.nombredivision
EMPL.quintonivelid, QN.nombrequintonivel

-- DESPUÉS
DOC.centrocostoid, CCO.nombrecentrocosto
DOC.divisionid, DIV.nombredivision
DOC.quintonivelid, QN.nombrequintonivel
```

### 2. sp_gestor/sp_gestorpersonas_listaxtipodoc_total.sql

**Cambios realizados:**

-   ✅ JOINs a tablas de niveles: Todos usan `DOC.*`
-   ✅ Permisos: Verifican contra `DOC.*`
-   ✅ Filtros idénticos al SP de listado (consistencia garantizada)
-   ✅ Agregados comentarios explicativos

**Impacto**: Ahora el total de registros coincide exactamente con los registros mostrados en el listado.

### 3. sp_gestor/sp_gestorpersonas_xrut.sql

**Cambios realizados:**

-   ✅ Permisos dinámicos: Cambiados de `EMPL.*` a `DOC.*`
-   ✅ Construcción SQL dinámica usando niveles históricos
-   ✅ Logging mejorado para debugging

**Código modificado:**

```sql
-- ANTES
INNER JOIN g_accesoxusuariodepartamento ADV
    ON ADV.lugarpagoid = EMPL.lugarpagoid        -- ❌ Nivel actual
   AND ADV.departamentoid = EMPL.departamentoid  -- ❌ Nivel actual

-- DESPUÉS
INNER JOIN g_accesoxusuariodepartamento ADV
    ON ADV.lugarpagoid = DOC.lugarpagoid1        -- ✅ Nivel histórico
   AND ADV.departamentoid = DOC.departamentoid   -- ✅ Nivel histórico
```

### 4. guia_dinamizacion_consultas_documentos.md

**Cambios realizados:**

-   ✅ Nueva sección: "Salvedad Crítica: Niveles Históricos vs Niveles Actuales"
-   ✅ Documentadas las diferencias entre `g_documentosinfo` y `empleados`
-   ✅ Agregada "Regla de Oro" con ejemplos de código correcto e incorrecto
-   ✅ Explicadas las consecuencias de mezclar fuentes
-   ✅ Actualizada versión a 1.3 con changelog completo

---

## 🧪 Casos de Prueba

### Caso 1: Empleado Trasladado

**Setup:**

```sql
-- Crear documento en Depto X
INSERT INTO g_documentosinfo (empleadoid, departamentoid, centrocostoid)
VALUES ('11111111-1', 'DEPTO-X', 'CC-100');

-- Trasladar empleado a Depto Y
UPDATE empleados
SET departamentoid = 'DEPTO-Y', centrocostoid = 'CC-200'
WHERE empleadoid = '11111111-1';

-- Usuario tiene acceso solo a Depto X
INSERT INTO g_accesoxusuariodepartamento
VALUES ('user123', 'EMP-A', 'LP-A', 'DEPTO-X');
```

**Resultado esperado con la solución:**

-   ✅ `sp_gestorpersonas_xrut`: Muestra al empleado SOLO si buscas por empleadoid directamente
-   ✅ `sp_gestorpersonas_listaxtipodoc`: Muestra los documentos del Depto X (porque el usuario tiene acceso a Depto X)
-   ✅ **Consistencia total**: Si aparece el empleado, aparecen sus documentos

### Caso 2: Permisos Limitados

**Setup:**

```sql
-- Usuario solo tiene acceso a CC-200
INSERT INTO g_accesoxusuarioccosto
VALUES ('user456', 'EMP-A', 'LP-A', 'DEPTO-Y', 'CC-200');

-- Empleado tiene documentos en CC-100 (histórico)
-- Empleado actual está en CC-200
```

**Resultado esperado:**

-   ❌ El usuario NO ve documentos antiguos (creados en CC-100)
-   ✅ El usuario SÍ verá documentos nuevos (creados después del traslado a CC-200)
-   ✅ **Lógica correcta**: Los permisos se aplican al contexto del documento, no del empleado

---

## 📊 Comparación Antes vs Después

| Aspecto               | ANTES (Incorrecto)                      | DESPUÉS (Correcto)           |
| --------------------- | --------------------------------------- | ---------------------------- |
| **Fuente de niveles** | Mezclaba `DOC.*` y `EMPL.*`             | Solo `DOC.*`                 |
| **Consistencia**      | ❌ Empleado aparece pero sin documentos | ✅ Total consistencia        |
| **Permisos**          | Verificaba ubicación actual             | Verifica ubicación histórica |
| **Auditoría**         | ❌ Pierde contexto histórico            | ✅ Mantiene contexto         |
| **Mantenibilidad**    | ❌ Difícil de entender                  | ✅ Lógica clara              |
| **Debugging**         | ❌ Confuso, inconsistente               | ✅ Logging detallado         |

---

## ⚠️ Impacto del Cambio

### Cambios en el Comportamiento

**Antes:**

-   Usuarios veían documentos basándose en la ubicación ACTUAL del empleado
-   Si un empleado se movía de Depto A a Depto B, usuarios de Depto B veían todos sus documentos históricos

**Después:**

-   Usuarios ven documentos basándose en la ubicación HISTÓRICA donde se creó el documento
-   Si un empleado se movió de Depto A a Depto B:
    -   Usuarios de Depto A ven documentos creados cuando estaba en Depto A
    -   Usuarios de Depto B ven documentos creados después del traslado

### ¿Es un Breaking Change?

**SÍ**, pero es la **corrección de un bug crítico** que estaba causando:

1. Inconsistencias en la UI
2. Confusión en usuarios
3. Problemas de auditoría
4. Falta de trazabilidad

### Migración

No se requiere migración de datos. Los cambios son solo en la lógica de consulta.

**Recomendación**: Comunicar a usuarios que ahora los documentos se muestran según su contexto histórico, no según la ubicación actual del empleado.

---

## 🎯 Beneficios de la Solución

### 1. Consistencia Total

-   Los 3 SPs ahora usan la misma lógica
-   Si un empleado aparece, sus documentos también aparecen

### 2. Auditoría Correcta

-   Los documentos mantienen su contexto histórico
-   Se puede rastrear dónde estaba un empleado al momento de firmar

### 3. Permisos Lógicos

-   Un documento del Depto X solo lo ven usuarios con acceso a Depto X
-   Aunque el empleado se haya movido a Depto Y

### 4. Trazabilidad

-   Se mantiene la historia completa
-   Cumple con requisitos de auditoría legal

### 5. Mantenibilidad

-   Código más claro y consistente
-   Comentarios explicativos en puntos críticos
-   Logging detallado para debugging

---

## 📚 Lecciones Aprendidas

### 1. Importancia de la Consistencia

Los documentos deben tratarse como **registros históricos inmutables**, no como datos en tiempo real que cambian con el empleado.

### 2. Documentación de Decisiones

La diferencia entre campos `lugarpagoid` vs `lugarpagoid1` era sutil pero crítica. Ahora está documentada.

### 3. Testing Exhaustivo

Este tipo de bugs solo aparecen cuando:

-   Hay traslados de empleados
-   El usuario consulta datos históricos
-   Se mezclan permisos y datos de diferentes épocas

### 4. Naming Conventions

La diferencia de nombre (`lugarpagoid1` vs `lugarpagoid`) ayuda a distinguir niveles históricos de actuales, pero debe estar bien documentada.

---

## 🔮 Próximos Pasos

1. **Revisar otros SPs del módulo Gestor** para verificar que usen la misma lógica
2. **Revisar módulo Docuflow** (`contratos`, `ContratoDatosVariables`) para inconsistencias similares
3. **Crear tests automatizados** para casos de empleados trasladados
4. **Actualizar documentación de usuario** sobre el comportamiento de permisos históricos
5. **Monitorear logs** para detectar casos edge que no se hayan considerado

---

## 👥 Contacto

**Autor**: Emanuel Cuello  
**Fecha**: 15 de Octubre, 2025  
**Módulo**: Gestor de Personas  
**Versión**: 1.0

---

## 📖 Referencias

-   [Guía de Dinamización de Consultas con Niveles](./guia_dinamizacion_consultas_documentos.md)
-   [Reglas de Niveles](./.cursor/rules/niveles.mdc)
-   [Store Procedures Gestor](./sp_gestor/)

---

## Anexo: Snippet de Código Reusable

Para futuros SPs, usar este patrón:

```sql
-- ✅ PATRÓN CORRECTO: Niveles desde documento histórico
IF v_niveles >= 3 THEN
    var_sql := var_sql || '
    INNER JOIN centroscosto AS CCO
        ON CCO.centrocostoid = DOC.centrocostoid      -- ← DOC, no EMPL
       AND CCO.lugarpagoid = DOC.lugarpagoid1         -- ← DOC, no EMPL
       AND CCO.departamentoid = DOC.departamentoid    -- ← DOC, no EMPL
       AND CCO.empresaid = DOC.empresaid';
END IF;

-- ✅ PATRÓN CORRECTO: Permisos desde documento histórico
IF v_niveles = 3 THEN
    var_sql := var_sql || '
    INNER JOIN g_accesoxusuarioccosto ACC
        ON ACC.centrocostoid = DOC.centrocostoid      -- ← DOC, no EMPL
       AND ACC.departamentoid = DOC.departamentoid    -- ← DOC, no EMPL
       AND ACC.lugarpagoid = DOC.lugarpagoid1         -- ← DOC, no EMPL
       AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
END IF;
```

**Recordatorio**: Siempre comentar `-- desde DOC` en puntos críticos para futuras referencias.
