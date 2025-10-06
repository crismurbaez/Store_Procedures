-- FUNCTION: public.sp_documentosvigentes_totalportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_totalportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_totalportiempo(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer,
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_pempleado character varying,
	p_prutempleado character varying,
	p_pusuarioid character varying,
	p_pfichaid integer,
	p_fechainicio date,
	p_fechafin date,
	p_prutempresa character varying,-- 
	p_plugarpagoid character varying,
	p_pnombrelugarpago character varying,
	p_pdepartamentoid character varying,
	p_pnombredepartamento character varying,
	p_pcentrocosto character varying,
	p_pnombrecentrocosto character varying,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
	p_pquintonivelid character varying DEFAULT '',
	p_pnombrequintonivel character varying DEFAULT '',
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql text;
    v_niveles integer;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Construir SELECT COUNT(*)
    var_sql := 'SELECT COUNT(*)';
    
    -- Construir FROM y JOINs base
    var_sql := var_sql || '
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
        LEFT JOIN workflowestadoprocesos WEP ON C.idwf = WEP.idworkflow AND C.idestado = WEP.idestadowf
        LEFT JOIN fichasdocumentos FD ON FD.documentoid = C.iddocumento AND FD.idfichaorigen = 2';
    
    -- Agregar JOINs de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.lugarpagoid = CDV.lugarpagoid AND DEP.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        LEFT JOIN centroscosto CC ON CC.centrocostoid = CDV.centrocosto AND CC.lugarpagoid = CDV.lugarpagoid AND CC.departamentoid = CDV.departamentoid AND CC.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto AND DIV.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid AND QN.empresaid = C.rutempresa';
    END IF;
    
    -- Agregar permisos dinámicos según nivel más alto disponible
    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
            AND ALP.lugarpagoid = CDV.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos ADV ON ADV.empresaid = C.rutempresa
            AND ADV.lugarpagoid = CDV.lugarpagoid
            AND ADV.departamentoid = CDV.departamentoid
            AND ADV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
            AND ACC.lugarpagoid = CDV.lugarpagoid
            AND ACC.departamentoid = CDV.departamentoid
            AND ACC.centrocostoid = CDV.centrocosto
            AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
            AND ADIV.lugarpagoid = CDV.lugarpagoid
            AND ADIV.departamentoid = CDV.departamentoid
            AND ADIV.centrocostoid = CDV.centrocosto
            AND ADIV.divisionid = CDV.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
            AND AQN.lugarpagoid = CDV.lugarpagoid
            AND AQN.departamentoid = CDV.departamentoid
            AND AQN.centrocostoid = CDV.centrocosto
            AND AQN.divisionid = CDV.divisionid
            AND AQN.quintonivelid = CDV.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;
    
    -- Construir condiciones WHERE base
    var_sql := var_sql || '
        WHERE C.eliminado IS FALSE';
    
    -- Agregar filtros condicionalmente
    IF p_pFirmante != '' THEN
        var_sql := var_sql || ' AND REP.nombre ILIKE ''%'' || ''' || p_pFirmante || ''' || ''%''';
    END IF;
    
    IF p_prutFirmante != '' THEN
        var_sql := var_sql || ' AND CF.rutfirmante LIKE ''%'' || ''' || p_prutFirmante || ''' || ''%''';
    END IF;
    
    IF p_pEmpleado != '' THEN
        var_sql := var_sql || ' AND PER.nombre ILIKE ''%'' || ''' || p_pEmpleado || ''' || ''%''';
    END IF;
    
    IF p_prutempleado != '' THEN
        var_sql := var_sql || ' AND PER.personaid LIKE ''%'' || ''' || p_prutempleado || ''' || ''%''';
    END IF;
    
    IF p_piddocumento != 0 THEN
        var_sql := var_sql || ' AND C.iddocumento = ' || p_piddocumento;
    END IF;
    
    IF p_pidtipodocumento != 0 THEN
        var_sql := var_sql || ' AND PL.idtipodoc = ' || p_pidtipodocumento;
    END IF;
    
    -- Filtro de estado de contrato
    IF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || ' AND C.idestado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato = -1 THEN
        var_sql := var_sql || ' AND C.idestado != 7';
    ELSIF p_pidestadocontrato = -2 THEN
        var_sql := var_sql || ' AND C.idestado IN (1,4,7)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (2,3,9,10,11)';
    END IF;
    
    IF p_pidtipofirma != 0 THEN
        var_sql := var_sql || ' AND C.idtipofirma = ' || p_pidtipofirma;
    END IF;
    
    IF p_pidproceso != 0 THEN
        var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso;
    END IF;
    
    IF p_pfichaid > 0 THEN
        var_sql := var_sql || ' AND FD.fichaid = ' || p_pfichaid;
    END IF;
    
    IF p_prutempresa != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ''' || p_prutempresa || '''';
    END IF;
    
    -- Agregar filtros de fecha condicionalmente
    IF p_fechainicio IS NOT NULL OR p_fechafin IS NOT NULL THEN
        IF p_fechainicio IS NOT NULL AND p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion BETWEEN ''' || p_fechainicio::text || ''' AND ''' || p_fechafin::text || '''';
        ELSIF p_fechainicio IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion >= ''' || p_fechainicio::text || '''';
        ELSIF p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion <= ''' || p_fechafin::text || '''';
        END IF;
    END IF;
    
    -- Debug: Mostrar SQL generado
    RAISE NOTICE 'SQL generado: %', var_sql;
    
    -- Agregar filtros dinámicos por nivel
    IF v_niveles >= 1 AND p_plugarpagoid != '' THEN
        var_sql := var_sql || ' AND CDV.lugarpagoid = ''' || p_plugarpagoid || '''';
    END IF;
    
    IF v_niveles >= 1 AND p_pnombrelugarpago != '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ''%'' || ''' || p_pnombrelugarpago || ''' || ''%''';
    END IF;
    
    IF v_niveles >= 2 AND p_pdepartamentoid != '' THEN
        var_sql := var_sql || ' AND CDV.departamentoid = ''' || p_pdepartamentoid || '''';
    END IF;
    
    IF v_niveles >= 2 AND p_pnombredepartamento != '' THEN
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ''%'' || ''' || p_pnombredepartamento || ''' || ''%''';
    END IF;
    
    IF v_niveles >= 3 AND p_pcentrocosto != '' THEN
        var_sql := var_sql || ' AND CDV.centrocosto = ''' || p_pcentrocosto || '''';
    END IF;
    
    IF v_niveles >= 3 AND p_pnombrecentrocosto != '' THEN
        var_sql := var_sql || ' AND CC.nombrecentrocosto ILIKE ''%'' || ''' || p_pnombrecentrocosto || ''' || ''%''';
    END IF;
    
    IF v_niveles >= 4 AND p_pdivisionid != '' THEN
        var_sql := var_sql || ' AND CDV.divisionid = ''' || p_pdivisionid || '''';
    END IF;
    
    IF v_niveles >= 4 AND p_pnombredivision != '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ''%'' || ''' || p_pnombredivision || ''' || ''%''';
    END IF;
    
    IF v_niveles = 5 AND p_pquintonivelid != '' THEN
        var_sql := var_sql || ' AND CDV.quintonivelid = ''' || p_pquintonivelid || '''';
    END IF;
    
    IF v_niveles = 5 AND p_pnombrequintonivel != '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ''%'' || ''' || p_pnombrequintonivel || ''' || ''%''';
    END IF;
    
    -- Ejecutar consulta dinámica
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS error, SQLERRM AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_documentosvigentes_totalportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)
    OWNER TO postgres;