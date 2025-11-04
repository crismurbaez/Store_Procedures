-- FUNCTION: public.sp_verificar_permiso_aprobar_documento(refcursor, integer, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_aprobar_documento(refcursor, integer, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_aprobar_documento(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_pidestadocontrato integer default 1,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    -- Obtener rol del usuario
    SELECT rolid INTO v_rolid FROM usuarios WHERE usuarioid = p_pusuarioid;
    
    IF v_rolid IS NULL THEN
        OPEN p_refcursor FOR 
            SELECT false AS tiene_permiso, 'Usuario no encontrado'::character varying AS mensaje;
        RETURN p_refcursor;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_APROBAR_DOCUMENTO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
        RAISE NOTICE 'v_rolid: %', v_rolid;
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM contratos C
     INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
     INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc
       AND T.tipousuarioid = ' || quote_literal(p_ptipousuarioid) || '
     INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento';
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN lugarespago LP ON LP.empresaid = C.RutEmpresa
         AND LP.lugarpagoid = CDV.LugarPagoid';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN departamentos DEP ON DEP.empresaid = C.RutEmpresa
         AND DEP.lugarpagoid = CDV.LugarPagoid
         AND DEP.departamentoid = CDV.departamentoid';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN centroscosto CCO ON CCO.empresaid = C.RutEmpresa
         AND CCO.lugarpagoid = CDV.LugarPagoid
         AND CCO.departamentoid = CDV.departamentoid
         AND CCO.centrocostoid = CDV.centrocosto';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN division DIV ON DIV.empresaid = C.RutEmpresa
         AND DIV.lugarpagoid = CDV.LugarPagoid
         AND DIV.departamentoid = CDV.departamentoid
         AND DIV.centrocostoid = CDV.centrocosto
         AND DIV.divisionid = CDV.divisionid';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN quinto_nivel QN ON QN.empresaid = C.RutEmpresa
         AND QN.lugarpagoid = CDV.LugarPagoid
         AND QN.departamentoid = CDV.departamentoid
         AND QN.centrocostoid = CDV.centrocosto
         AND QN.divisionid = CDV.divisionid
         AND QN.quintonivelid = CDV.quintonivelid';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.RutEmpresa
         AND ALP.lugarpagoid = CDV.LugarPagoid
         AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.RutEmpresa
         AND ADIV.lugarpagoid = CDV.LugarPagoid
         AND ADIV.departamentoid = CDV.departamentoid
         AND ADIV.centrocostoid = CDV.centrocosto
         AND ADIV.divisionid = CDV.divisionid
         AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.RutEmpresa
         AND AQN.lugarpagoid = CDV.LugarPagoid
         AND AQN.departamentoid = CDV.departamentoid
         AND AQN.centrocostoid = CDV.centrocosto
         AND AQN.divisionid = CDV.divisionid
         AND AQN.quintonivelid = CDV.quintonivelid
         AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- Validación de rol público si aplica
    IF v_rolid = 2 THEN
        var_sql := var_sql ||
        ' INNER JOIN empleados Emp ON CDV.Rut = Emp.empleadoid
          AND Emp.rolid = ' || v_rolid;
    END IF;

    -- WHERE: documento específico, no eliminado y en el estado correcto
    var_sql := var_sql ||
    ' WHERE C.idDocumento = ' || p_iddocumento || '
      AND C.Eliminado = false
      AND C.idEstado = ' || p_pidestadocontrato;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;-- FUNCTION: public.sp_verificar_permiso_consultageneral(refcursor, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_consultageneral(refcursor, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_consultageneral(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql       text;
    v_niveles     integer;
    v_rolid       integer;
    v_estado      text;
    v_existe      boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_CONSULTAGENERAL ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
        RAISE NOTICE 'p_tipousuarioid: %', p_tipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Obtener rolid y estado del usuario
    SELECT COALESCE(u.rolid, 2), COALESCE(u.idestadoempleado, 'A')
    INTO v_rolid, v_estado
    FROM usuarios u
    WHERE u.usuarioid = p_usuarioid;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
        RAISE NOTICE 'v_rolid: %', v_rolid;
        RAISE NOTICE 'v_estado: %', v_estado;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles del documento
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM g_documentosinfo DOC
     JOIN g_tiposdocumentosxperfil GTX 
         ON GTX.tipodocumentoid = DOC.tipodocumentoid
        AND GTX.tipousuarioid = ' || p_tipousuarioid || '
     JOIN empleados EMPL 
         ON EMPL.empleadoid = DOC.empleadoid
     JOIN empresas EMP 
         ON EMP.rutempresa = EMPL.rutempresa';
    
    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS (desde EMPL) ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN lugarespago LP 
         ON LP.empresaid = EMPL.rutempresa
        AND LP.lugarpagoid = EMPL.lugarpagoid';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN departamentos DP 
         ON DP.empresaid = EMPL.rutempresa
        AND DP.lugarpagoid = EMPL.lugarpagoid
        AND DP.departamentoid = EMPL.departamentoid';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN centroscosto CCO 
         ON CCO.empresaid = EMPL.rutempresa
        AND CCO.centrocostoid = EMPL.centrocostoid
        AND CCO.lugarpagoid = EMPL.lugarpagoid
        AND CCO.departamentoid = EMPL.departamentoid';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN division DIV 
         ON DIV.empresaid = EMPL.rutempresa
        AND DIV.divisionid = EMPL.divisionid
        AND DIV.lugarpagoid = EMPL.lugarpagoid
        AND DIV.departamentoid = EMPL.departamentoid
        AND DIV.centrocostoid = EMPL.centrocostoid';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN quinto_nivel QN 
         ON QN.empresaid = EMPL.rutempresa
        AND QN.quintonivelid = EMPL.quintonivelid
        AND QN.lugarpagoid = EMPL.lugarpagoid
        AND QN.departamentoid = EMPL.departamentoid
        AND QN.centrocostoid = EMPL.centrocostoid
        AND QN.divisionid = EMPL.divisionid';
    END IF;
    
    -- INNER JOIN con permisos del GESTOR según nivel (usando EMPL.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS DEL GESTOR (desde EMPL) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: g_accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariolugarespago AS ALP 
         ON ALP.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ALP.empresaid = EMPL.rutempresa
        AND ALP.lugarpagoid = EMPL.lugarpagoid';
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: g_accesoxusuariodepartamento';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodepartamento AS ADV 
         ON ADV.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ADV.empresaid = EMPL.rutempresa
        AND ADV.lugarpagoid = EMPL.lugarpagoid
        AND ADV.departamentoid = EMPL.departamentoid';
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: g_accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioccosto AS ACC 
         ON ACC.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ACC.empresaid = EMPL.rutempresa
        AND ACC.lugarpagoid = EMPL.lugarpagoid
        AND ACC.departamentoid = EMPL.departamentoid
        AND ACC.centrocostoid = EMPL.centrocostoid';
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: g_accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodivision AS ADIV 
         ON ADIV.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ADIV.empresaid = EMPL.rutempresa
        AND ADIV.lugarpagoid = EMPL.lugarpagoid
        AND ADIV.departamentoid = EMPL.departamentoid
        AND ADIV.centrocostoid = EMPL.centrocostoid
        AND ADIV.divisionid = EMPL.divisionid';
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: g_accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioquintonivel AS AQN 
         ON AQN.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND AQN.empresaid = EMPL.rutempresa
        AND AQN.lugarpagoid = EMPL.lugarpagoid
        AND AQN.departamentoid = EMPL.departamentoid
        AND AQN.centrocostoid = EMPL.centrocostoid
        AND AQN.divisionid = EMPL.divisionid
        AND AQN.quintonivelid = EMPL.quintonivelid';
    END IF;

    -- JOINs adicionales
    var_sql := var_sql || '
     JOIN tipogestor TD ON TD.idtipogestor = DOC.tipodocumentoid
     JOIN personas PER ON PER.personaid = EMPL.empleadoid';

    -- WHERE: documento específico
    var_sql := var_sql ||
    ' WHERE DOC.documentoid = ' || p_documentoid;
    
    -- Validación de rol (si es rol 2 = público, no mostrar rol 1 = administrador)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
      AND COALESCE(EMPL.rolid, 2) <> 1';
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando filtro de rol: usuario público no ve administradores';
        END IF;
    END IF;
    
    -- Validación de estado del empleado (si usuario está activo, no mostrar empleados eliminados)
    IF v_estado = 'A' THEN
        var_sql := var_sql || '
      AND COALESCE(EMPL.idestadoempleado, ''A'') <> ''E''';
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando filtro de estado: no mostrar empleados eliminados';
        END IF;
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_descargamasiva(refcursor, integer, integer, character varying, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_descargamasiva(refcursor, integer, integer, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_descargamasiva(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_estadoid character varying DEFAULT '',
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_DESCARGAMASIVA ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
        RAISE NOTICE 'p_tipousuarioid: %', p_tipousuarioid;
        RAISE NOTICE 'p_estadoid: %', p_estadoid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles del documento
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM g_documentosinfo AS DOC
     INNER JOIN g_tiposdocumentosxperfil
         ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
        AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
     INNER JOIN empleados AS EMPL
         ON EMPL.empleadoid = DOC.empleadoid';
    
    -- Validación de estado del empleado (igual que el código PHP)
    IF p_estadoid = 'A' THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando filtro de estado: solo empleados activos';
        END IF;
        var_sql := var_sql || '
        AND EMPL.idestadoempleado = ''A''';
    ELSIF p_estadoid <> '' AND p_estadoid <> 'A' THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando filtro de estado: solo empleados NO activos';
        END IF;
        var_sql := var_sql || '
        AND EMPL.idestadoempleado <> ''A''';
    END IF;
    
    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS (desde EMPL) ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN lugarespago AS LP
         ON LP.lugarpagoid = EMPL.lugarpagoid
        AND LP.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN departamentos AS DP
         ON DP.departamentoid = EMPL.departamentoid
        AND DP.lugarpagoid = EMPL.lugarpagoid
        AND DP.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN centroscosto CCO
         ON CCO.empresaid = EMPL.rutempresa
        AND CCO.centrocostoid = EMPL.centrocostoid
        AND CCO.lugarpagoid = EMPL.lugarpagoid
        AND CCO.departamentoid = EMPL.departamentoid';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN division DIV
         ON DIV.empresaid = EMPL.rutempresa
        AND DIV.divisionid = EMPL.divisionid
        AND DIV.lugarpagoid = EMPL.lugarpagoid
        AND DIV.departamentoid = EMPL.departamentoid
        AND DIV.centrocostoid = EMPL.centrocostoid';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN quinto_nivel QN
         ON QN.empresaid = EMPL.rutempresa
        AND QN.quintonivelid = EMPL.quintonivelid
        AND QN.lugarpagoid = EMPL.lugarpagoid
        AND QN.departamentoid = EMPL.departamentoid
        AND QN.centrocostoid = EMPL.centrocostoid
        AND QN.divisionid = EMPL.divisionid';
    END IF;
    
    -- INNER JOIN con permisos del GESTOR según nivel (usando EMPL.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS DEL GESTOR (desde EMPL) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: g_accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariolugarespago AS ALP
         ON ALP.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ALP.empresaid = EMPL.rutempresa
        AND ALP.lugarpagoid = EMPL.lugarpagoid';
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: g_accesoxusuariodepartamento';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodepartamento AS ADV
         ON ADV.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ADV.empresaid = EMPL.rutempresa
        AND ADV.lugarpagoid = EMPL.lugarpagoid
        AND ADV.departamentoid = EMPL.departamentoid';
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: g_accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioccosto AS ACC
         ON ACC.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ACC.empresaid = EMPL.rutempresa
        AND ACC.lugarpagoid = EMPL.lugarpagoid
        AND ACC.departamentoid = EMPL.departamentoid
        AND ACC.centrocostoid = EMPL.centrocostoid';
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: g_accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodivision AS ADIV
         ON ADIV.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND ADIV.empresaid = EMPL.rutempresa
        AND ADIV.lugarpagoid = EMPL.lugarpagoid
        AND ADIV.departamentoid = EMPL.departamentoid
        AND ADIV.centrocostoid = EMPL.centrocostoid
        AND ADIV.divisionid = EMPL.divisionid';
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: g_accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioquintonivel AS AQN
         ON AQN.usuarioid = ' || quote_literal(p_usuarioid) || '
        AND AQN.empresaid = EMPL.rutempresa
        AND AQN.lugarpagoid = EMPL.lugarpagoid
        AND AQN.departamentoid = EMPL.departamentoid
        AND AQN.centrocostoid = EMPL.centrocostoid
        AND AQN.divisionid = EMPL.divisionid
        AND AQN.quintonivelid = EMPL.quintonivelid';
    END IF;

    -- JOINs adicionales
    var_sql := var_sql || '
     INNER JOIN tipogestor AS TD
         ON TD.idtipogestor = DOC.tipodocumentoid
     INNER JOIN personas AS PER
         ON PER.personaid = EMPL.empleadoid
     INNER JOIN empresas AS EMP
         ON EMP.rutempresa = EMPL.rutempresa';

    -- WHERE: documento específico
    var_sql := var_sql ||
    ' WHERE DOC.documentoid = ' || p_documentoid;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_docvigentes_porprocesos(refcursor, integer, integer, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_docvigentes_porprocesos(refcursor, integer, integer, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_docvigentes_porprocesos(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_pidestadocontrato integer DEFAULT 0,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_DOCVIGENTES_PORPROCESOS ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
    END IF;
    
    -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_rolid: %', v_rolid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM contratos C
     JOIN plantillas PL ON PL.idplantilla = C.idplantilla
     JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc
         AND T.tipousuarioid = ' || p_ptipousuarioid || '
     JOIN empresas E ON E.rutempresa = C.rutempresa
     JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento';
    
    -- Agregar JOIN a empleados SOLO si el rol es público (2)
    IF v_rolid = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN de empleados para rol público (2)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN empleados Emp ON CDV.rut = Emp.empleadoid
         AND Emp.rolid = ' || v_rolid;
    END IF;
    
    var_sql := var_sql || '
     JOIN personas PER ON PER.personaid = CDV.rut';
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
     LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid
         AND LP.empresaid = C.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
     LEFT JOIN departamentos DEP ON DEP.lugarpagoid = CDV.lugarpagoid
         AND DEP.departamentoid = CDV.departamentoid
         AND DEP.empresaid = C.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
     LEFT JOIN centroscosto CC ON CC.empresaid = C.rutempresa
         AND CC.lugarpagoid = CDV.lugarpagoid
         AND CC.departamentoid = CDV.departamentoid
         AND CC.centrocostoid = CDV.centrocosto';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
     LEFT JOIN division DIV ON DIV.empresaid = C.rutempresa
         AND DIV.lugarpagoid = CDV.lugarpagoid
         AND DIV.departamentoid = CDV.departamentoid
         AND DIV.centrocostoid = CDV.centrocosto
         AND DIV.divisionid = CDV.divisionid';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
     LEFT JOIN quinto_nivel QN ON QN.empresaid = C.rutempresa
         AND QN.lugarpagoid = CDV.lugarpagoid
         AND QN.departamentoid = CDV.departamentoid
         AND QN.centrocostoid = CDV.centrocosto
         AND QN.divisionid = CDV.divisionid
         AND QN.quintonivelid = CDV.quintonivelid';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
     INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
         AND ALP.lugarpagoid = CDV.lugarpagoid
         AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
     INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa
         AND ACC.lugarpagoid = CDV.lugarpagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
     INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
         AND ACC.lugarpagoid = CDV.lugarpagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
     INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
         AND ADIV.lugarpagoid = CDV.lugarpagoid
         AND ADIV.departamentoid = CDV.departamentoid
         AND ADIV.centrocostoid = CDV.centrocosto
         AND ADIV.divisionid = CDV.divisionid
         AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
     INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
         AND AQN.lugarpagoid = CDV.lugarpagoid
         AND AQN.departamentoid = CDV.departamentoid
         AND AQN.centrocostoid = CDV.centrocosto
         AND AQN.divisionid = CDV.divisionid
         AND AQN.quintonivelid = CDV.quintonivelid
         AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- WHERE: documento específico y no eliminado
    var_sql := var_sql ||
    ' WHERE C.iddocumento = ' || p_iddocumento || '
      AND C.eliminado = FALSE';
    
    -- Validación de estado del contrato (igual que el SP original)
    IF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || '
      AND C.idestado IN (1,2,3,4,6,8,9,10,11)';
        IF p_debug = 1 THEN
            RAISE NOTICE 'Filtro estado < 0: estados múltiples (1,2,3,4,6,8,9,10,11)';
        END IF;
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || '
      AND C.idestado IN (2,3,10,11)';
        IF p_debug = 1 THEN
            RAISE NOTICE 'Filtro estado = 0: estados (2,3,10,11)';
        END IF;
    ELSIF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || '
      AND C.idestado = ' || p_pidestadocontrato;
        IF p_debug = 1 THEN
            RAISE NOTICE 'Filtro estado específico: %', p_pidestadocontrato;
        END IF;
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_docvigentes_tiempo(refcursor, integer, integer, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_docvigentes_tiempo(refcursor, integer, integer, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_docvigentes_tiempo(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_pidestadocontrato integer DEFAULT 0,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_DOCVIGENTES_TIEMPO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM contratos C
     JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento
     JOIN personas PER ON PER.personaid = CDV.rut
     JOIN empresas E ON E.rutempresa = C.rutempresa
     LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND C.idestado = CF.idestado
     LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante
     JOIN plantillas PL ON PL.idplantilla = C.idplantilla
     JOIN tipodocumentos TD ON PL.idtipodoc = TD.idtipodoc
     JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc AND T.tipousuarioid = ' || p_ptipousuarioid || '
     JOIN procesos P ON C.idproceso = P.idproceso
     JOIN contratosestados CE ON C.idestado = CE.idestado
     JOIN firmastipos FT ON C.idtipofirma = FT.idtipofirma
     LEFT JOIN workflowestadoprocesos WEP ON C.idwf = WEP.idworkflow AND C.idestado = WEP.idestadowf';
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.lugarpagoid = CDV.lugarpagoid AND DEP.empresaid = C.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN centroscosto CC ON CC.centrocostoid = CDV.centrocosto AND CC.lugarpagoid = CDV.lugarpagoid AND CC.departamentoid = CDV.departamentoid AND CC.empresaid = C.rutempresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto AND DIV.empresaid = C.rutempresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid AND QN.empresaid = C.rutempresa';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
           AND ALP.lugarpagoid = CDV.lugarpagoid
           AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodepartamentos ADV ON ADV.empresaid = C.rutempresa
           AND ADV.lugarpagoid = CDV.lugarpagoid
           AND ADV.departamentoid = CDV.departamentoid
           AND ADV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
           AND ACC.lugarpagoid = CDV.lugarpagoid
           AND ACC.departamentoid = CDV.departamentoid
           AND ACC.centrocostoid = CDV.centrocosto
           AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
           AND ADIV.lugarpagoid = CDV.lugarpagoid
           AND ADIV.departamentoid = CDV.departamentoid
           AND ADIV.centrocostoid = CDV.centrocosto
           AND ADIV.divisionid = CDV.divisionid
           AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
           AND AQN.lugarpagoid = CDV.lugarpagoid
           AND AQN.departamentoid = CDV.departamentoid
           AND AQN.centrocostoid = CDV.centrocosto
           AND AQN.divisionid = CDV.divisionid
           AND AQN.quintonivelid = CDV.quintonivelid
           AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- WHERE: documento específico, no eliminado
    var_sql := var_sql ||
    ' WHERE C.iddocumento = ' || p_iddocumento || '
      AND C.eliminado IS FALSE';
    
    -- Validación de estado del contrato (igual que el SP original)
    IF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || '
      AND C.idestado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato = -1 THEN
        var_sql := var_sql || '
      AND C.idestado != 7';
    ELSIF p_pidestadocontrato = -2 THEN
        var_sql := var_sql || '
      AND C.idestado IN (1,4,7)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || '
      AND C.idestado IN (2,3,9,10,11)';
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_eliminar_documento(refcursor, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_eliminar_documento(refcursor, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_eliminar_documento(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_ELIMINAR_DOCUMENTO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql := '
        SELECT COUNT(*) > 0 AS existe
        FROM Contratos C
        INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento
        INNER JOIN Personas PER ON PER.personaid = CDV.Rut
        INNER JOIN Empresas E ON E.RutEmpresa = C.RutEmpresa
        LEFT JOIN ContratoFirmantes CF ON CF.idDocumento = C.idDocumento AND C.idEstado = CF.idEstado
        LEFT JOIN Personas REP ON REP.personaid = CF.RutFirmante
        INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
        INNER JOIN TipoDocumentos TD ON TD.idTipoDoc = PL.idTipoDoc
        INNER JOIN Procesos P ON P.idProceso = C.idProceso
        INNER JOIN ContratosEstados CE ON CE.idEstado = C.idEstado
        INNER JOIN FirmasTipos FT ON FT.idTipoFirma = C.idTipoFirma
        LEFT JOIN WorkflowEstadoProcesos WEP ON C.idWF = WEP.idWorkflow AND C.idEstado = WEP.idEstadoWF
        INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc AND T.tipousuarioid = ' || p_ptipousuarioid;
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
        LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.LugarPagoid AND LP.empresaid = C.RutEmpresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
        LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.empresaid = C.RutEmpresa AND DEP.lugarpagoid = CDV.LugarPagoid';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
        LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.departamentoid = CDV.departamentoid AND CCO.lugarpagoid = CDV.LugarPagoid AND CCO.empresaid = C.RutEmpresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
        LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.centrocostoid = CDV.centrocosto AND DIV.departamentoid = CDV.departamentoid AND DIV.lugarpagoid = CDV.LugarPagoid AND DIV.empresaid = C.RutEmpresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.divisionid = CDV.divisionid AND QN.centrocostoid = CDV.centrocosto AND QN.departamentoid = CDV.departamentoid AND QN.lugarpagoid = CDV.LugarPagoid AND QN.empresaid = C.RutEmpresa';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.RutEmpresa AND ALP.lugarpagoid = CDV.LugarPagoid AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.RutEmpresa AND ACC.lugarpagoid = CDV.LugarPagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.RutEmpresa AND ACC.lugarpagoid = CDV.LugarPagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.RutEmpresa AND ADIV.lugarpagoid = CDV.LugarPagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.RutEmpresa AND AQN.lugarpagoid = CDV.LugarPagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- WHERE: documento específico y no eliminado
    var_sql := var_sql || '
        WHERE C.idDocumento = ' || p_iddocumento || '
          AND C.Eliminado = false';

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_firmatercero_documento(refcursor, integer, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_firmatercero_documento(refcursor, integer, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_firmatercero_documento(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_pidestadocontrato integer DEFAULT 0,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_FIRMATERCERO_DOCUMENTO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
    END IF;
    
    -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_rolid: %', v_rolid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM contratos c
     INNER JOIN plantillas p
         ON p.idplantilla = c.idplantilla
     INNER JOIN tiposdocumentosxperfil t
         ON p.idplantilla = t.idtipodoc
        AND t.tipousuarioid = ' || p_ptipousuarioid || '
     INNER JOIN empresas e
         ON e.rutempresa = c.rutempresa
     INNER JOIN contratodatosvariables cdv
         ON cdv.iddocumento = c.iddocumento
     INNER JOIN personas per
         ON per.personaid = cdv.rut';
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN lugarespago lp
           ON lp.lugarpagoid = cdv.lugarpagoid
          AND lp.empresaid = c.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN departamentos dep
           ON dep.lugarpagoid = cdv.lugarpagoid
          AND dep.departamentoid = cdv.departamentoid
          AND dep.empresaid = c.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN centroscosto cco
           ON cco.centrocostoid = cdv.centrocosto
          AND cco.lugarpagoid = cdv.lugarpagoid
          AND cco.departamentoid = cdv.departamentoid
          AND cco.empresaid = c.rutempresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN division div
           ON div.divisionid = cdv.divisionid
          AND div.lugarpagoid = cdv.lugarpagoid
          AND div.departamentoid = cdv.departamentoid
          AND div.centrocostoid = cdv.centrocosto
          AND div.empresaid = c.rutempresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN quinto_nivel qn
           ON qn.quintonivelid = cdv.quintonivelid
          AND qn.lugarpagoid = cdv.lugarpagoid
          AND qn.departamentoid = cdv.departamentoid
          AND qn.centrocostoid = cdv.centrocosto
          AND qn.divisionid = cdv.divisionid
          AND qn.empresaid = c.rutempresa';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariolugarespago alp
           ON alp.empresaid = c.rutempresa
          AND alp.lugarpagoid = cdv.lugarpagoid
          AND alp.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodepartamentos acc
           ON acc.empresaid = c.rutempresa
          AND acc.lugarpagoid = cdv.lugarpagoid
          AND acc.departamentoid = cdv.departamentoid
          AND acc.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioccosto acc
           ON acc.empresaid = c.rutempresa
          AND acc.lugarpagoid = cdv.lugarpagoid
          AND acc.departamentoid = cdv.departamentoid
          AND acc.centrocostoid = cdv.centrocosto
          AND acc.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodivision adiv
           ON adiv.empresaid = c.rutempresa
          AND adiv.lugarpagoid = cdv.lugarpagoid
          AND adiv.departamentoid = cdv.departamentoid
          AND adiv.centrocostoid = cdv.centrocosto
          AND adiv.divisionid = cdv.divisionid
          AND adiv.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioquintonivel aqn
           ON aqn.empresaid = c.rutempresa
          AND aqn.lugarpagoid = cdv.lugarpagoid
          AND aqn.departamentoid = cdv.departamentoid
          AND aqn.centrocostoid = cdv.centrocosto
          AND aqn.divisionid = cdv.divisionid
          AND aqn.quintonivelid = cdv.quintonivelid
          AND aqn.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- Aplicar filtro por ROL si es necesario (2 = Público)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
       INNER JOIN empleados emp
           ON cdv.rut = emp.empleadoid
          AND emp.rolid = ' || v_rolid;
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando filtro por ROL: %', v_rolid;
        END IF;
    END IF;

    -- WHERE: documento específico, no eliminado, tipo de usuario y estado correcto
    var_sql := var_sql ||
    ' WHERE c.iddocumento = ' || p_iddocumento || '
      AND c.eliminado = false
      AND t.tipousuarioid = ' || p_ptipousuarioid;
    
    -- Validación de estado del contrato (igual que el SP original)
    IF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || '
      AND c.idestado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || '
      AND c.idestado IN (1,2,3,6,8,9,10,11)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || '
      AND c.idestado IN (2,3,10,11)';
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_firmaunitaria_documento(refcursor, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_firmaunitaria_documento(refcursor, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_firmaunitaria_documento(
    p_refcursor refcursor,
    p_iddocumento integer,
	p_tipousuario integer,
    p_firmante character varying,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
    v_nl       text := CHR(13) || CHR(10);
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_FIRMAUNITARIA_DOCUMENTO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_firmante: %', p_firmante;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql := 
        'SELECT COUNT(*) > 0 AS existe ' || v_nl ||
        'FROM contratos C ' || v_nl ||
        'INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento ' || v_nl ||
        'INNER JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND CF.idestado = C.idestado ' || v_nl ||
        'INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla ' || v_nl ||
        'INNER JOIN empresas E ON E.rutempresa = C.rutempresa ' || v_nl ||
        'INNER JOIN personas P ON P.personaid = CDV.rut ' || v_nl;
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || 
            'LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa ' || v_nl;
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || 
            'LEFT JOIN departamentos DP ON DP.lugarpagoid = CDV.lugarpagoid AND DP.empresaid = C.rutempresa AND DP.departamentoid = CDV.departamentoid ' || v_nl;
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || 
            'LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.lugarpagoid = CDV.lugarpagoid AND CCO.departamentoid = CDV.departamentoid AND CCO.empresaid = C.rutempresa ' || v_nl;
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || 
            'LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto AND DIV.empresaid = C.rutempresa ' || v_nl;
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || 
            'LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid AND QN.empresaid = C.rutempresa ' || v_nl;
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || 
            'INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa AND ALP.lugarpagoid = CDV.lugarpagoid AND ALP.usuarioid = ' || quote_literal(p_firmante) || v_nl;
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || 
            'INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = ' || quote_literal(p_firmante) || v_nl;
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || 
            'INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = ' || quote_literal(p_firmante) || v_nl;
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || 
            'INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa AND ADIV.lugarpagoid = CDV.lugarpagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = ' || quote_literal(p_firmante) || v_nl;
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || 
            'INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa AND AQN.lugarpagoid = CDV.lugarpagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = ' || quote_literal(p_firmante) || v_nl;
    END IF;

    -- WHERE: documento específico, firmante específico y condiciones de firma
    var_sql := var_sql || 
        'WHERE C.iddocumento = ' || p_iddocumento || v_nl ||
        '  AND C.eliminado = FALSE ' || v_nl ||
        '  AND CF.rutfirmante = ' || quote_literal(p_firmante) || v_nl ||
        '  AND CF.idestado IN (2, 10) ' || v_nl ||
        '  AND CF.firmado = FALSE';

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;
-- FUNCTION: public.sp_verificar_permiso_gestor_tipodoc(refcursor, integer, character varying, character varying, integer, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_gestor_tipodoc(refcursor, integer, character varying, character varying, integer, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_gestor_tipodoc(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_GESTOR_TIPODOC ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_empleadoid: %', p_empleadoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
        RAISE NOTICE 'p_tipodocumentoid: %', p_tipodocumentoid;
        RAISE NOTICE 'p_tipousuarioid: %', p_tipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles del documento
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM g_documentosinfo AS DOC
     INNER JOIN g_tiposdocumentosxperfil
         ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
        AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
     INNER JOIN empleados AS EMPL
         ON EMPL.empleadoid = DOC.empleadoid
        AND EMPL.RutEmpresa = DOC.empresaid
     INNER JOIN TipoGestor AS TG
         ON TG.idTipoGestor = DOC.tipodocumentoid
     INNER JOIN personas AS PER
         ON PER.personaid = EMPL.empleadoid
     INNER JOIN empresas AS EMP
         ON EMP.RutEmpresa = DOC.empresaid';
    
    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS (desde EMPL) ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN lugarespago AS LP
         ON LP.lugarpagoid = EMPL.lugarpagoid
        AND LP.empresaid = EMPL.RutEmpresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN departamentos AS DP
         ON DP.departamentoid = EMPL.departamentoid
        AND DP.lugarpagoid = EMPL.lugarpagoid
        AND DP.empresaid = EMPL.RutEmpresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN centroscosto AS CCO
         ON CCO.centrocostoid = EMPL.centrocostoid
        AND CCO.lugarpagoid = EMPL.lugarpagoid
        AND CCO.departamentoid = EMPL.departamentoid
        AND CCO.empresaid = EMPL.RutEmpresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN division AS DIV
         ON DIV.divisionid = EMPL.divisionid
        AND DIV.lugarpagoid = EMPL.lugarpagoid
        AND DIV.departamentoid = EMPL.departamentoid
        AND DIV.centrocostoid = EMPL.centrocostoid
        AND DIV.empresaid = EMPL.RutEmpresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN quinto_nivel AS QN
         ON QN.quintonivelid = EMPL.quintonivelid
        AND QN.lugarpagoid = EMPL.lugarpagoid
        AND QN.departamentoid = EMPL.departamentoid
        AND QN.centrocostoid = EMPL.centrocostoid
        AND QN.divisionid = EMPL.divisionid
        AND QN.empresaid = EMPL.RutEmpresa';
    END IF;
    
    -- INNER JOIN con permisos del GESTOR (usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS DEL GESTOR (INNER JOIN desde EMPL) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: g_accesoxusuariolugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariolugarespago ALP
         ON ALP.empresaid = EMPL.RutEmpresa
        AND ALP.lugarpagoid = EMPL.lugarpagoid
        AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: g_accesoxusuariodepartamento (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodepartamento ACC
         ON ACC.empresaid = EMPL.RutEmpresa
        AND ACC.lugarpagoid = EMPL.lugarpagoid
        AND ACC.departamentoid = EMPL.departamentoid
        AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: g_accesoxusuarioccosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioccosto ACC
         ON ACC.empresaid = EMPL.RutEmpresa
        AND ACC.lugarpagoid = EMPL.lugarpagoid
        AND ACC.departamentoid = EMPL.departamentoid
        AND ACC.centrocostoid = EMPL.centrocostoid
        AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: g_accesoxusuariodivision (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodivision ADIV
         ON ADIV.empresaid = EMPL.RutEmpresa
        AND ADIV.lugarpagoid = EMPL.lugarpagoid
        AND ADIV.departamentoid = EMPL.departamentoid
        AND ADIV.centrocostoid = EMPL.centrocostoid
        AND ADIV.divisionid = EMPL.divisionid
        AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: g_accesoxusuarioquintonivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioquintonivel AQN
         ON AQN.empresaid = EMPL.RutEmpresa
        AND AQN.lugarpagoid = EMPL.lugarpagoid
        AND AQN.departamentoid = EMPL.departamentoid
        AND AQN.centrocostoid = EMPL.centrocostoid
        AND AQN.divisionid = EMPL.divisionid
        AND AQN.quintonivelid = EMPL.quintonivelid
        AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
    END IF;

    -- WHERE: documento específico, empleado específico y tipo de documento
    var_sql := var_sql ||
    ' WHERE DOC.documentoid = ' || p_documentoid || '
      AND EMPL.empleadoid = ' || quote_literal(p_empleadoid) || '
      AND DOC.tipodocumentoid = ' || p_tipodocumentoid;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_importaciongestor(refcursor, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_importaciongestor(refcursor, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_importaciongestor(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_estado   text;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_IMPORTACIONGESTOR ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
    END IF;
    
    -- Obtener rol y estado del usuario (aunque no se usan en la validación)
    SELECT COALESCE(u.rolid, 2), COALESCE(u.idestadoempleado, 'A')
    INTO v_rolid, v_estado
    FROM usuarios u
    WHERE u.usuarioid = p_usuarioid;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_rolid: %', v_rolid;
        RAISE NOTICE 'v_estado: %', v_estado;
    END IF;

    -- Construir consulta para verificar permisos
    -- IMPORTANTE: Esta tabla NO tiene validación por niveles, es más simple
    -- Solo valida que el documento exista y NO esté indexado aún (indexado = 0)
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM documentosindexar DOC
     LEFT JOIN tipogestor TD ON TD.idtipogestor = DOC.tipodocumentoid
     LEFT JOIN personas PER ON PER.personaid = DOC.empleadoid
     LEFT JOIN empresas EMP ON EMP.rutempresa = DOC.empresaid
     WHERE DOC.id = ' || p_documentoid || '
       AND DOC.indexado = 0';

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe o ya fue indexado'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_verificar_permiso_misdocumentos(refcursor, integer, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_misdocumentos(refcursor, integer, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_misdocumentos(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_tipousuarioid integer,
    p_firmante character varying,
    p_pidestadocontrato integer DEFAULT -1,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_MISDOCUMENTOS ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_firmante: %', p_firmante;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- Replica la lógica de sp_documentos_listado_misdocumentos
    var_sql := '
        SELECT COUNT(*) > 0 AS existe
        FROM Contratos C
        INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
        INNER JOIN TipoDocumentos TD ON TD.idTipoDoc = PL.idTipoDoc
        INNER JOIN Procesos P ON P.idProceso = C.idProceso
        INNER JOIN ContratosEstados CE ON CE.idEstado = C.idEstado
        INNER JOIN FirmasTipos FT ON FT.idTipoFirma = C.idTipoFirma
        INNER JOIN Empresas E ON E.RutEmpresa = C.RutEmpresa
        LEFT JOIN WorkflowEstadoProcesos WEP ON C.idWF = WEP.idWorkflow AND C.idEstado = WEP.idEstadoWF
        INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento AND CDV.Rut = ' || quote_literal(p_firmante) || '
        INNER JOIN Personas PER ON PER.personaid = CDV.Rut
        WHERE C.idDocumento = ' || p_iddocumento || '
          AND C.Eliminado = false';
    
    -- Validación de estado del contrato (lógica especial de MisDocumentos)
    -- Por defecto (-1): muestra todos los estados permitidos (3,6) o (8 con RutRechazo)
    IF p_pidestadocontrato = 3 OR p_pidestadocontrato = 6 THEN
        -- Estado específico 3 o 6
        var_sql := var_sql || '
          AND C.idEstado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato = 8 THEN
        -- Estado 8 solo si el usuario es quien rechazó
        var_sql := var_sql || '
          AND C.idEstado = 8 
          AND C.RutRechazo = ' || quote_literal(p_firmante);
    ELSIF p_pidestadocontrato < 0 THEN
        -- Todos los estados permitidos (default -1)
        var_sql := var_sql || '
          AND (C.idEstado IN (3,6) OR (C.idEstado = 8 AND C.RutRechazo = ' || quote_literal(p_firmante) || '))';
    ELSIF p_pidestadocontrato = 0 THEN
        -- Solo estado 3
        var_sql := var_sql || '
          AND C.idEstado IN (3)';
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_pendientes_personal(refcursor, integer, character varying, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_pendientes_personal(refcursor, integer, character varying, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_pendientes_personal(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_tipousuarioid integer,
    p_rutempleado character varying,
    p_firmante character varying DEFAULT '',
    p_pidestadocontrato integer DEFAULT 0,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_PENDIENTES_PERSONAL ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_rutempleado: %', p_rutempleado;
        RAISE NOTICE 'p_firmante: %', p_firmante;
        RAISE NOTICE 'p_pidestadocontrato: %', p_pidestadocontrato;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- Replica la lógica de sp_documentos_listado_pendientes_personal
    var_sql := '
        SELECT COUNT(*) > 0 AS existe
        FROM contratos C
        INNER JOIN empresas E ON E.rutempresa = C.rutempresa
        INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento AND C.rutempresa = E.rutempresa
        INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla
        INNER JOIN personas P ON P.personaid = CDV.rut';
    
    -- JOIN condicional con contratofirmantes (solo si se proporciona firmante)
    IF p_firmante <> '' THEN
        var_sql := var_sql || '
        INNER JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento 
          AND CF.rutfirmante = ' || quote_literal(p_firmante) || '
          AND CF.idestado = C.idestado';
    END IF;
    
    -- WHERE: documento específico, empleado específico y no eliminado
    var_sql := var_sql || '
        WHERE C.iddocumento = ' || p_iddocumento || '
          AND C.eliminado = false
          AND CDV.rut = ' || quote_literal(p_rutempleado);
    
    -- Validación de estado del contrato (igual que el SP original)
    IF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || '
          AND C.idestado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || '
          AND C.idestado IN (3,6,8,9,10)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || '
          AND C.idestado IN (3,10)';
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_pendientes_representante(refcursor, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_pendientes_representante(refcursor, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_pendientes_representante(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_tipousuarioid integer,
    p_firmante character varying,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_PENDIENTES_REPRESENTANTE ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_firmante: %', p_firmante;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- Replica la lógica de sp_documentos_listado_pendientes_representante
    var_sql := '
        SELECT COUNT(*) > 0 AS existe
        FROM contratos C
        INNER JOIN Empresas E ON E.RutEmpresa = C.RutEmpresa
        INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento AND C.RutEmpresa = E.RutEmpresa
        INNER JOIN ContratoFirmantes CF ON CF.idDocumento = C.idDocumento AND CF.idEstado = C.idEstado
        INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
        INNER JOIN Personas P ON P.personaid = CDV.Rut
        WHERE C.idDocumento = ' || p_iddocumento || '
          AND C.Eliminado = false
          AND CF.RutFirmante = ' || quote_literal(p_firmante) || '
          AND CF.idEstado IN (2, 10)
          AND CF.Firmado = false';

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_verificar_permiso_pt_gestor_tipodoc(refcursor, integer, character varying, character varying, integer, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_pt_gestor_tipodoc(refcursor, integer, character varying, character varying, integer, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_pt_gestor_tipodoc(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_PT_GESTOR_TIPODOC ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_empleadoid: %', p_empleadoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
        RAISE NOTICE 'p_tipodocumentoid: %', p_tipodocumentoid;
        RAISE NOTICE 'p_tipousuarioid: %', p_tipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles del documento (DOC.*)
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM g_documentosinfo AS DOC
     JOIN g_tiposdocumentosxperfil AS TXP
       ON TXP.tipodocumentoid = DOC.tipodocumentoid
      AND TXP.tipousuarioid   = ' || p_tipousuarioid || '
     JOIN empleados AS EMPL
       ON EMPL.empleadoid = DOC.empleadoid
      AND EMPL.rutempresa = DOC.empresaid
     JOIN tipogestor AS TG
       ON TG.idtipogestor = DOC.tipodocumentoid
     JOIN personas AS PER
       ON PER.personaid = EMPL.empleadoid
     JOIN empresas AS EMP
       ON EMP.rutempresa = DOC.empresaid';
    
    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS (desde EMPL) ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN lugarespago AS LP
       ON LP.lugarpagoid = EMPL.lugarpagoid
      AND LP.empresaid   = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN departamentos AS DP
       ON DP.departamentoid = EMPL.departamentoid
      AND DP.lugarpagoid    = EMPL.lugarpagoid
      AND DP.empresaid      = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN centroscosto AS CCO
       ON CCO.centrocostoid = EMPL.centrocostoid
      AND CCO.lugarpagoid    = EMPL.lugarpagoid
      AND CCO.departamentoid = EMPL.departamentoid
      AND CCO.empresaid      = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN division AS DIV
       ON DIV.divisionid      = EMPL.divisionid
      AND DIV.lugarpagoid    = EMPL.lugarpagoid
      AND DIV.departamentoid = EMPL.departamentoid
      AND DIV.centrocostoid  = EMPL.centrocostoid
      AND DIV.empresaid      = EMPL.rutempresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     JOIN quinto_nivel AS QN
       ON QN.quintonivelid    = EMPL.quintonivelid
      AND QN.lugarpagoid      = EMPL.lugarpagoid
      AND QN.departamentoid   = EMPL.departamentoid
      AND QN.centrocostoid    = EMPL.centrocostoid
      AND QN.divisionid       = EMPL.divisionid
      AND QN.empresaid        = EMPL.rutempresa';
    END IF;

    -- WHERE: documento específico, empleado específico y tipo de documento específico
    var_sql := var_sql ||
    ' WHERE DOC.documentoid = ' || p_documentoid || '
      AND EMPL.empleadoid = ' || quote_literal(p_empleadoid) || '
      AND DOC.tipodocumentoid = ' || p_tipodocumentoid;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_validaciones(refcursor, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_validaciones(refcursor, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_validaciones(
    p_refcursor refcursor,
    p_documentoid integer,
    p_empleadoid character varying,
    p_usuarioid character varying,
    p_tipousuarioid integer,
    p_tipodocumentoid integer,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_niveles  integer;
    v_rolid    integer;
    v_estado   character varying(1);
    v_existe   boolean := false;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_VALIDACIONES ===';
        RAISE NOTICE 'p_documentoid: %', p_documentoid;
        RAISE NOTICE 'p_usuarioid: %', p_usuarioid;
        RAISE NOTICE 'p_tipousuarioid: %', p_tipousuarioid;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Obtener rol y estado del usuario
    SELECT COALESCE(rolid, 2), COALESCE(idEstadoEmpleado, 'A')
    INTO v_rolid, v_estado
    FROM usuarios
    WHERE usuarioid = p_usuarioid;
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'v_niveles: %', v_niveles;
        RAISE NOTICE 'v_rolid: %', v_rolid;
        RAISE NOTICE 'v_estado: %', v_estado;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    -- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles del documento
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM g_documentosinfo AS DOC
     INNER JOIN tipogestor AS TD ON TD.idtipogestor = DOC.tipodocumentoid
     INNER JOIN g_tiposdocumentosxperfil ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
         AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
     INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
     INNER JOIN personas AS PER ON PER.personaid = DOC.empleadoid
     INNER JOIN empresas AS EMP ON EMP.rutempresa = DOC.empresaid';
    
    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS (desde EMPL) ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN lugarespago AS LP ON LP.lugarpagoid = EMPL.lugarpagoid
         AND LP.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN departamentos AS DP ON DP.departamentoid = EMPL.departamentoid
         AND DP.lugarpagoid = EMPL.lugarpagoid
         AND DP.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN centroscosto AS CCO ON CCO.centrocostoid = EMPL.centrocostoid
         AND CCO.lugarpagoid = EMPL.lugarpagoid
         AND CCO.departamentoid = EMPL.departamentoid
         AND CCO.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN division AS DIV ON DIV.divisionid = EMPL.divisionid
         AND DIV.lugarpagoid = EMPL.lugarpagoid
         AND DIV.departamentoid = EMPL.departamentoid
         AND DIV.centrocostoid = EMPL.centrocostoid
         AND DIV.empresaid = EMPL.rutempresa';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
        END IF;
        var_sql := var_sql || '
     INNER JOIN quinto_nivel AS QN ON QN.quintonivelid = EMPL.quintonivelid
         AND QN.lugarpagoid = EMPL.lugarpagoid
         AND QN.departamentoid = EMPL.departamentoid
         AND QN.centrocostoid = EMPL.centrocostoid
         AND QN.divisionid = EMPL.divisionid
         AND QN.empresaid = EMPL.rutempresa';
    END IF;
    
    -- INNER JOIN con permisos del GESTOR según nivel (usando EMPL.*)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS DEL GESTOR (desde EMPL) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: g_accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariolugarespago ALP ON ALP.empresaid = DOC.empresaid
         AND ALP.lugarpagoid = EMPL.lugarpagoid
         AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: g_accesoxusuariodepartamento';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodepartamento ADV ON ADV.empresaid = DOC.empresaid
         AND ADV.lugarpagoid = EMPL.lugarpagoid
         AND ADV.departamentoid = EMPL.departamentoid
         AND ADV.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: g_accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioccosto ACC ON ACC.empresaid = DOC.empresaid
         AND ACC.lugarpagoid = EMPL.lugarpagoid
         AND ACC.departamentoid = EMPL.departamentoid
         AND ACC.centrocostoid = EMPL.centrocostoid
         AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: g_accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuariodivision ADIV ON ADIV.empresaid = DOC.empresaid
         AND ADIV.lugarpagoid = EMPL.lugarpagoid
         AND ADIV.departamentoid = EMPL.departamentoid
         AND ADIV.centrocostoid = EMPL.centrocostoid
         AND ADIV.divisionid = EMPL.divisionid
         AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: g_accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
     INNER JOIN g_accesoxusuarioquintonivel AQN ON AQN.empresaid = DOC.empresaid
         AND AQN.lugarpagoid = EMPL.lugarpagoid
         AND AQN.departamentoid = EMPL.departamentoid
         AND AQN.centrocostoid = EMPL.centrocostoid
         AND AQN.divisionid = EMPL.divisionid
         AND AQN.quintonivelid = EMPL.quintonivelid
         AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
    END IF;

    -- WHERE: documento específico y sin número de contrato
    var_sql := var_sql ||
    ' WHERE DOC.documentoid = ' || p_documentoid || '
      AND COALESCE(DOC.NumeroContrato, 0) = 0';
    
    -- Validación compleja de rol y estado del empleado (4 casos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO VALIDACION DE ROL Y ESTADO ===';
        RAISE NOTICE 'Evaluando casos - Rol: %, Estado: %', v_rolid, v_estado;
    END IF;
    
    IF v_rolid = 1 AND v_estado = 'F' THEN
        -- Caso 1: Rol privado + Estado finiquitado → Puede ver todo
        IF p_debug = 1 THEN
            RAISE NOTICE 'Caso 1: Rol privado + Estado finiquitado - Sin filtros adicionales';
        END IF;
        -- NO agregar filtros de rol ni estado (puede ver todo)
    ELSIF v_rolid != 1 AND v_estado = 'F' THEN
        -- Caso 2: Rol público + Estado finiquitado → No puede ver rol privado
        IF p_debug = 1 THEN
            RAISE NOTICE 'Caso 2: Rol público + Estado finiquitado - Excluyendo rol privado';
        END IF;
        var_sql := var_sql || '
      AND COALESCE(EMPL.rolid, 2) <> 1';
    ELSIF v_rolid = 1 AND v_estado = 'A' THEN
        -- Caso 3: Rol privado + Estado activo → No puede ver finiquitados
        IF p_debug = 1 THEN
            RAISE NOTICE 'Caso 3: Rol privado + Estado activo - Excluyendo finiquitados';
        END IF;
        var_sql := var_sql || '
      AND COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E''';
    ELSIF v_rolid = 2 AND v_estado = 'A' THEN
        -- Caso 4: Rol público + Estado activo → No puede ver rol privado ni finiquitados
        IF p_debug = 1 THEN
            RAISE NOTICE 'Caso 4: Rol público + Estado activo - Excluyendo rol privado y finiquitados';
        END IF;
        var_sql := var_sql || '
      AND COALESCE(EMPL.rolid, 2) <> 1
      AND COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E''';
    ELSE
        IF p_debug = 1 THEN
            RAISE NOTICE 'Caso no contemplado - Rol: %, Estado: %', v_rolid, v_estado;
        END IF;
    END IF;

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


