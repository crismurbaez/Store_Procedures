# Guía Genérica: Dinamización de Consultas de Documentos con Niveles y Permisos

## Propósito

Esta guía establece el patrón estándar para crear stored procedures de consulta de documentos que soporten niveles y permisos dinámicos, aplicable tanto para Docuflow como para Gestor.

## Principios Fundamentales

### 1. Niveles Dinámicos

-   Los niveles se consultan dinámicamente desde `niveles_estructura`
-   Solo se incluyen JOINs, campos y filtros de niveles disponibles
-   Soporte para 1-5 niveles según configuración del cliente

### 2. Permisos Jerárquicos

-   Los permisos se aplican al nivel más alto disponible
-   Si hay nivel 5, solo se verifica `accesoxusuarioquintonivel`
-   Si hay nivel 4, solo se verifica `accesoxusuariodivision`
-   Y así sucesivamente hasta nivel 1

### 3. Construcción Dinámica de SQL

-   Campos SELECT se agregan condicionalmente
-   JOINs se construyen según niveles disponibles
-   Filtros se aplican solo para niveles habilitados

## Estructura Base del SP

### Parámetros Estándar

```sql
CREATE OR REPLACE FUNCTION public.sp_[nombre]_listado(
    p_refcursor refcursor,
    p_tipousuarioid integer,
    p_pagina integer,
    p_decuantos numeric,
    p_usuarioid character varying,
    -- Filtros base
    p_documentoid integer DEFAULT 0,
    p_tipodocumentoid integer DEFAULT 0,
    p_estadodocumento integer DEFAULT 0,
    -- Filtros de empresa y empleado
    p_rutempresa character varying DEFAULT '',
    p_rutempleado character varying DEFAULT '',
    p_nombreempleado character varying DEFAULT '',
    -- Filtros de niveles (opcionales)
    p_lugarpagoid character varying DEFAULT '',
    p_nombrelugarpago character varying DEFAULT '',
    p_departamentoid character varying DEFAULT '',
    p_nombredepartamento character varying DEFAULT '',
    p_centrocostoid character varying DEFAULT '',
    p_nombrecentrocosto character varying DEFAULT '',
    p_divisionid character varying DEFAULT '',
    p_nombredivision character varying DEFAULT '',
    p_quintonivelid character varying DEFAULT '',
    p_nombrequintonivel character varying DEFAULT '',
    -- Parámetros adicionales específicos del SP
    p_debug smallint DEFAULT 0
)
```

### Variables de Declaración

```sql
DECLARE
    var_sql text;
    var_count_sql text;
    v_niveles integer;
    v_rolid integer;
    v_estado character varying(1);
    v_inicio integer;
    v_fin integer;
    var_log_message text;
BEGIN
```

## Implementación Paso a Paso

### 1. Inicialización y Logging

```sql
    -- Log de inicio
    var_log_message := 'INICIO sp_[nombre]_listado - Usuario: ' || COALESCE(p_usuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol y estado del usuario
    SELECT COALESCE(rolid, 2), COALESCE(idEstadoEmpleado, 'A')
    INTO v_rolid, v_estado
    FROM usuarios
    WHERE usuarioid = p_usuarioid;

    -- Calcular paginación
    v_inicio := (p_pagina - 1) * p_decuantos + 1;
    v_fin := p_pagina * p_decuantos;
```

### 2. Construcción Dinámica de Campos SELECT

```sql
    -- Campos base (siempre presentes)
    var_sql := '
        SELECT
            DOC.documentoid,
            DOC.tipodocumentoid,
            TD.nombre AS nombredocumento,
            DOC.empleadoid,
            COALESCE(PER.nombre, '''') || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''') AS nombre,
            DOC.empresaid,
            EMP.RazonSocial AS nombreempresa,
            TO_CHAR(DOC.fechadocumento, ''DD-MM-YYYY'') AS fechadocumento,
            TO_CHAR(DOC.fechacreacion, ''DD-MM-YYYY'') AS fechacreacion,
            ROW_NUMBER() OVER(ORDER BY DOC.fechadocumento DESC) AS rownum';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', LP.lugarpagoid, LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', DP.departamentoid, DP.nombredepartamento';
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', CCO.centrocostoid, CCO.nombrecentrocosto';
        RAISE NOTICE 'Agregando campo nivel 3: centroscosto';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', DIV.divisionid, DIV.nombredivision';
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', QN.quintonivelid, QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;
```

### 3. FROM y JOINs Base

```sql
    -- FROM y JOINs base (ajustar según tabla principal)
    var_sql := var_sql || '
        FROM [tabla_principal] AS DOC
        INNER JOIN [tabla_tipos] AS TD ON TD.[id_tipo] = DOC.[id_tipo]
        INNER JOIN [tabla_perfiles] ON [tabla_perfiles].[id_tipo] = DOC.[id_tipo]
            AND [tabla_perfiles].tipousuarioid = ' || p_tipousuarioid || '
        INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
        INNER JOIN personas AS PER ON PER.personaid = DOC.empleadoid
        INNER JOIN empresas AS EMP ON EMP.rutempresa = DOC.empresaid';
```

### 4. JOINs Dinámicos por Nivel

```sql
    -- JOINs de niveles dinámicos (solo agregar los que están disponibles)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        INNER JOIN lugarespago AS LP ON LP.lugarpagoid = EMPL.lugarpagoid
            AND LP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        INNER JOIN departamentos AS DP ON DP.departamentoid = EMPL.departamentoid
            AND DP.lugarpagoid = EMPL.lugarpagoid
            AND DP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        INNER JOIN centroscosto AS CCO ON CCO.centrocostoid = EMPL.centrocostoid
            AND CCO.lugarpagoid = EMPL.lugarpagoid
            AND CCO.departamentoid = EMPL.departamentoid
            AND CCO.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        INNER JOIN division AS DIV ON DIV.divisionid = EMPL.divisionid
            AND DIV.lugarpagoid = EMPL.lugarpagoid
            AND DIV.departamentoid = EMPL.departamentoid
            AND DIV.centrocostoid = EMPL.centrocostoid
            AND DIV.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN quinto_nivel AS QN ON QN.quintonivelid = EMPL.quintonivelid
            AND QN.lugarpagoid = EMPL.lugarpagoid
            AND QN.departamentoid = EMPL.departamentoid
            AND QN.centrocostoid = EMPL.centrocostoid
            AND QN.divisionid = EMPL.divisionid
            AND QN.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;
```

**⚠️ NOTA**: Si los datos vienen de `ContratoDatosVariables` en lugar de `empleados`, usar:

-   `CDV.centrocosto` en lugar de `EMPL.centrocostoid` (nivel 3)
-   `CDV.centrocosto` en lugar de `EMPL.centrocostoid` (nivel 4 y 5)

### 5. Condiciones WHERE Base

```sql
    var_sql := var_sql || '
        WHERE 1=1';

    -- Filtros base específicos del SP
    IF p_documentoid != 0 THEN
        var_sql := var_sql || ' AND DOC.documentoid = ' || p_documentoid;
    END IF;

    IF p_tipodocumentoid != 0 THEN
        var_sql := var_sql || ' AND DOC.tipodocumentoid = ' || p_tipodocumentoid;
    END IF;

    IF p_estadodocumento != 0 THEN
        var_sql := var_sql || ' AND DOC.estadodocumento = ' || p_estadodocumento;
    END IF;

    IF p_rutempresa != '' THEN
        var_sql := var_sql || ' AND DOC.empresaid = ''' || p_rutempresa || '''';
    END IF;

    IF p_rutempleado != '' THEN
        var_sql := var_sql || ' AND DOC.empleadoid ILIKE ''' || '%' || p_rutempleado || '%' || '''';
    END IF;

    IF p_nombreempleado != '' THEN
        var_sql := var_sql || ' AND (PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''')) ILIKE ''' || '%' || p_nombreempleado || '%' || '''';
    END IF;
```

### 6. Filtros Dinámicos por Nivel

```sql
    -- Filtros dinámicos para cada nivel disponible
    IF v_niveles >= 1 AND p_lugarpagoid != '' THEN
        var_sql := var_sql || ' AND EMPL.lugarpagoid = ''' || p_lugarpagoid || '''';
    END IF;

    IF v_niveles >= 1 AND p_nombrelugarpago != '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ''' || '%' || p_nombrelugarpago || '%' || '''';
    END IF;

    IF v_niveles >= 2 AND p_departamentoid != '' THEN
        var_sql := var_sql || ' AND EMPL.departamentoid = ''' || p_departamentoid || '''';
    END IF;

    IF v_niveles >= 2 AND p_nombredepartamento != '' THEN
        var_sql := var_sql || ' AND DP.nombredepartamento ILIKE ''' || '%' || p_nombredepartamento || '%' || '''';
    END IF;

    IF v_niveles >= 3 AND p_centrocostoid != '' THEN
        var_sql := var_sql || ' AND EMPL.centrocostoid = ''' || p_centrocostoid || '''';
    END IF;

    IF v_niveles >= 3 AND p_nombrecentrocosto != '' THEN
        var_sql := var_sql || ' AND CCO.nombrecentrocosto ILIKE ''' || '%' || p_nombrecentrocosto || '%' || '''';
    END IF;

    IF v_niveles >= 4 AND p_divisionid != '' THEN
        var_sql := var_sql || ' AND EMPL.divisionid = ''' || p_divisionid || '''';
    END IF;

    IF v_niveles >= 4 AND p_nombredivision != '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ''' || '%' || p_nombredivision || '%' || '''';
    END IF;

    IF v_niveles = 5 AND p_quintonivelid != '' THEN
        var_sql := var_sql || ' AND EMPL.quintonivelid = ''' || p_quintonivelid || '''';
    END IF;

    IF v_niveles = 5 AND p_nombrequintonivel != '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ''' || '%' || p_nombrequintonivel || '%' || '''';
    END IF;
```

### 7. Permisos Dinámicos por Nivel

**IMPORTANTE**: Los permisos deben aplicarse usando `INNER JOIN` en lugar de `EXISTS` para mejor performance y funcionalidad correcta.

```sql
    -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN [prefijo_]accesoxusuariolugarespago ALP ON ALP.empresaid = DOC.empresaid
            AND ALP.lugarpagoid = EMPL.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN [prefijo_]accesoxusuariodepartamentos ACC ON ACC.empresaid = DOC.empresaid
            AND ACC.lugarpagoid = EMPL.lugarpagoid
            AND ACC.departamentoid = EMPL.departamentoid
            AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN [prefijo_]accesoxusuarioccosto ACC ON ACC.empresaid = DOC.empresaid
            AND ACC.lugarpagoid = EMPL.lugarpagoid
            AND ACC.departamentoid = EMPL.departamentoid
            AND ACC.centrocostoid = EMPL.centrocostoid
            AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN [prefijo_]accesoxusuariodivision ADIV ON ADIV.empresaid = DOC.empresaid
            AND ADIV.lugarpagoid = EMPL.lugarpagoid
            AND ADIV.departamentoid = EMPL.departamentoid
            AND ADIV.centrocostoid = EMPL.centrocostoid
            AND ADIV.divisionid = EMPL.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN [prefijo_]accesoxusuarioquintonivel AQN ON AQN.empresaid = DOC.empresaid
            AND AQN.lugarpagoid = EMPL.lugarpagoid
            AND AQN.departamentoid = EMPL.departamentoid
            AND AQN.centrocostoid = EMPL.centrocostoid
            AND AQN.divisionid = EMPL.divisionid
            AND AQN.quintonivelid = EMPL.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;
```

**Nota sobre el orden**: Los JOINs de permisos deben ir **DESPUÉS** de los JOINs de niveles pero **ANTES** de los filtros WHERE para mantener el flujo lógico correcto del SQL.

### 8. Ejecución de la Consulta

```sql
    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida (primeros 500 caracteres): %', LEFT(var_sql, 500);

    -- Agregar paginación
    var_sql := 'SELECT * FROM (' || var_sql || ') AS ResultadoPaginado
               WHERE rownum BETWEEN ' || v_inicio || ' AND ' || v_fin;

    RAISE NOTICE 'Ejecutando consulta de listado con paginación';

    -- Abrir cursor con los resultados
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
```

### 9. Manejo de Errores

```sql
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_[nombre]_listado: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_[nombre]_listado: %', SQLERRM;
END;
```

## Diferencias entre Docuflow y Gestor

### Prefijos de Tablas de Acceso

-   **Docuflow**: `accesoxusuario[nivel]`
-   **Gestor**: `g_accesoxusuario[nivel]`

### Tablas Principales

-   **Docuflow**: `contratos`, `ContratoDatosVariables`
-   **Gestor**: `g_documentosinfo`

### Campos de Identificación

-   **Docuflow**: `idDocumento`, `RutEmpresa`, `Rut`
-   **Gestor**: `documentoid`, `empresaid`, `empleadoid`

### ⚠️ **SALVEDAD IMPORTANTE: Diferencias en Campos de Centro de Costo**

**CRÍTICO**: El campo de centro de costo tiene nombres diferentes según la tabla de origen:

-   **Tabla `empleados`**: `centrocostoid` (con "id" al final)
-   **Tabla `ContratoDatosVariables`**: `centrocosto` (sin "id" al final)

```sql
-- INCORRECTO - Causa error si se usa desde ContratoDatosVariables
AND ACC.centrocostoid = EMPL.centrocostoid

-- CORRECTO - Usar el nombre correcto según la tabla origen
AND ACC.centrocostoid = CDV.centrocosto  -- Si viene de ContratoDatosVariables
AND ACC.centrocostoid = EMPL.centrocostoid  -- Si viene de empleados
```

**Esta diferencia puede causar errores de SQL y pérdida de tiempo en debugging.**

## Nota sobre Consultas de Totales

Las consultas de totales (conteo de registros) generalmente se manejan en stored procedures separados, no en el mismo SP del listado. Esto permite:

-   Mejor separación de responsabilidades
-   Optimización específica para cada tipo de consulta
-   Mantenimiento más sencillo
-   Reutilización de lógica común

**IMPORTANTE**: El SP de totales debe tener **EXACTAMENTE** los mismos filtros que el SP de listado para garantizar consistencia en los resultados.

## Errores Comunes a Evitar

### 1. ❌ Usar EXISTS en lugar de INNER JOIN para Permisos

```sql
-- INCORRECTO - No funciona correctamente
AND EXISTS (
    SELECT 1 FROM accesoxusuariodepartamentos
    WHERE usuarioid = 'usuario' AND ...
)

-- CORRECTO - Funciona correctamente
INNER JOIN accesoxusuariodepartamentos ACC ON
    ACC.usuarioid = 'usuario' AND ...
```

### 2. ❌ Orden Incorrecto de JOINs

```sql
-- INCORRECTO - Permisos antes de JOINs de niveles
INNER JOIN accesoxusuariodepartamentos ACC ON ...
LEFT JOIN departamentos DEP ON ...

-- CORRECTO - JOINs de niveles antes de permisos
LEFT JOIN departamentos DEP ON ...
INNER JOIN accesoxusuariodepartamentos ACC ON ...
```

### 3. ❌ Filtros Inconsistentes entre Listado y Total

-   El SP de listado tiene filtros que el SP de total no tiene
-   Esto causa discrepancias en los conteos vs registros mostrados

### 4. ❌ Confundir Nombres de Campos de Centro de Costo

```sql
-- INCORRECTO - Mezclar nombres de diferentes tablas
AND ACC.centrocostoid = CDV.centrocostoid  -- ERROR: CDV.centrocostoid no existe

-- CORRECTO - Usar el nombre correcto según la tabla
AND ACC.centrocostoid = CDV.centrocosto   -- ✅ CDV usa "centrocosto"
AND ACC.centrocostoid = EMPL.centrocostoid  -- ✅ EMPL usa "centrocostoid"
```

## Checklist de Implementación

### Antes de Implementar

-   [ ] Verificar existencia de función `CONSULTAR_NIVELES()`
-   [ ] Verificar campos de niveles en tabla principal
-   [ ] Verificar existencia de tablas de acceso
-   [ ] Verificar estructura de tabla `empleados`

### Durante la Implementación

-   [ ] Agregar logging detallado
-   [ ] Probar con diferentes configuraciones de niveles
-   [ ] Verificar performance con grandes volúmenes
-   [ ] Validar filtros por nivel

### Después de Implementar

-   [ ] Actualizar documentación
-   [ ] Probar con datos reales
-   [ ] Monitorear performance
-   [ ] Actualizar tests unitarios

## Ejemplos de Uso

### SP para Docuflow

```sql
-- Ejemplo: sp_documentosporaprobar_listado
-- Tabla principal: contratos
-- Prefijo: (sin prefijo)
-- Campos: idDocumento, RutEmpresa, Rut
```

### SP para Gestor

```sql
-- Ejemplo: sp_validaciones_listado
-- Tabla principal: g_documentosinfo
-- Prefijo: g_
-- Campos: documentoid, empresaid, empleadoid
```

## Notas Importantes

1. **Performance**: Los JOINs dinámicos pueden afectar performance, monitorear
2. **Logging**: Usar RAISE NOTICE para debugging, deshabilitar en producción
3. **Seguridad**: Siempre usar quote_literal() para parámetros de texto
4. **Mantenibilidad**: Documentar cambios y versiones del SP
5. **Testing**: Probar con diferentes configuraciones de niveles
6. **Permisos**: **CRÍTICO** - Usar INNER JOIN para permisos, NO EXISTS para garantizar funcionamiento correcto
7. **Orden de JOINs**: Los permisos deben ir después de los JOINs de niveles pero antes de los filtros WHERE

## Versión

-   **Fecha**: 2025-01-02
-   **Versión**: 1.2
-   **Autor**: Sistema de Documentación
-   **Cambios v1.1**:
    -   Corregida sección de permisos dinámicos (INNER JOIN vs EXISTS)
    -   Agregada sección de errores comunes
    -   Actualizada nota sobre consistencia entre SPs de listado y total
-   **Cambios v1.2**:
    -   Agregada salvedad crítica sobre diferencias en nombres de campos de centro de costo
    -   Agregado error común #4 sobre confusión de nombres de campos
    -   Actualizada sección de JOINs con nota sobre ContratoDatosVariables vs empleados
