-- FUNCTION: public.sp_consultageneral_listado(refcursor, integer, character varying, character varying, character varying, character varying, character varying, integer, integer, character varying, date, date, character varying, integer, numeric)

-- DROP FUNCTION IF EXISTS public.sp_consultageneral_listado(refcursor, integer, character varying, character varying, character varying, character varying, character varying, integer, integer, character varying, date, date, character varying, integer, numeric);

CREATE OR REPLACE FUNCTION public.sp_consultageneral_listado(
	p_refcursor refcursor,
	ptipousuarioid integer,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocostoid character varying,
	pdivisionid character varying,
    pquintonivelid character varying,  -- SE AGREGA PARA QUINTO NIVEL
	agrupadorid integer,
	ptipodocumentoid integer,
	pempleadoid character varying,
	pfechadesde date,
	pfechahasta date,
	pusuarioid character varying,
	pagina integer,
	decuantos numeric)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_niveles    integer;
    sql_text     text;
    offset_start int;
    rolid_local  integer;
    estado_local text;
    var_cursor   alias for p_refcursor;
BEGIN
    -- Obtener niveles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- calcular rolid y estado
    SELECT COALESCE(u.rolid, 2), COALESCE(u.idestadoempleado, 'A')
      INTO rolid_local, estado_local
      FROM usuarios u
     WHERE u.usuarioid = pusuarioid;

    -- construir SQL principal
        sql_text := '
        SELECT 
            DOC.documentoid,
            DOC.tipodocumentoid,
            TD.nombre AS "nombredocumento",
            DOC.empleadoid,
            COALESCE(PER.nombre, '''') || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''') AS "nombre",
            DOC.empresaid,
            EMP.razonsocial AS "nombreempresa",
            DOC.fechadocumento,
            DOC.fechacreacion,
            DOC.fechatermino, ';
            IF v_niveles >= 1 THEN
                sql_text := 
                    sql_text || 'LP.lugarpagoid, LP.nombrelugarpago, ';
            END IF;
            IF v_niveles >= 2 THEN
                sql_text := 
                    sql_text || 'DP.departamentoid, DP.nombredepartamento, ';
            END IF;
            IF v_niveles >= 3 THEN
                sql_text := 
                    sql_text || 'CCO.centrocostoid, CCO.nombrecentrocosto, ';
            END IF;
            IF v_niveles >= 4 THEN
                sql_text := 
                    sql_text || 'DIV.divisionid, DIV.nombredivision, ';
            END IF;
            IF v_niveles = 5 THEN
                sql_text := 
                    sql_text || 'QN.quintonivelid, QN.nombrequintonivel, ';
            END IF;
        sql_text := 
            sql_text ||
            'COALESCE(DOC.numerocontrato, 0) AS "nrocontrato",
            ROW_NUMBER() OVER (ORDER BY DOC.fechadocumento) AS "rownum"
        FROM g_documentosinfo DOC
        JOIN g_tiposdocumentosxperfil GTX ON GTX.tipodocumentoid = DOC.tipodocumentoid
                                        AND GTX.tipousuarioid = ' || ptipousuarioid || '
        JOIN empleados EMPL ON EMPL.empleadoid = DOC.empleadoid
        JOIN empresas EMP ON EMP.rutempresa = EMPL.rutempresa '; 

                IF v_niveles >= 1 THEN
                    sql_text := 
                        sql_text ||
                        'JOIN lugarespago LP ON LP.empresaid = EMPL.rutempresa 
                            AND LP.lugarpagoid = EMPL.lugarpagoid  ';
                    IF v_niveles = 1 THEN
                        sql_text := 
                            sql_text ||
                            'INNER JOIN g_accesoxusuariolugarespago AS ALP ON ALP.usuarioid = ' || quote_literal(pusuarioid) || ' 
                                AND ALP.empresaid = EMPL.rutempresa 
                                AND ALP.lugarpagoid = EMPL.lugarpagoid ';
                    END IF;
                END IF;
                IF v_niveles >= 2 THEN
                    sql_text := 
                        sql_text ||
                        'JOIN departamentos DP ON DP.empresaid = EMPL.rutempresa 
                            AND DP.lugarpagoid = EMPL.lugarpagoid 
                            AND DP.departamentoid = EMPL.departamentoid ';
                    IF v_niveles = 2 THEN
                        sql_text := 
                            sql_text ||
                                'INNER JOIN g_accesoxusuariodepartamento AS ADV ON ADV.usuarioid = ' || quote_literal(pusuarioid) || ' 
                                    AND ADV.empresaid = EMPL.rutempresa 
                                    AND ADV.lugarpagoid = EMPL.lugarpagoid 
                                    AND ADV.departamentoid = EMPL.departamentoid ';
                    END IF;
                END IF;
                IF v_niveles >= 3 THEN
                    sql_text := 
                        sql_text ||
                        'JOIN centroscosto CCO ON  CCO.empresaid = EMPL.rutempresa 
                            AND CCO.centrocostoid = EMPL.centrocostoid 
                            AND CCO.lugarpagoid = EMPL.lugarpagoid 
                            AND CCO.departamentoid = EMPL.departamentoid ';
                    IF v_niveles = 3 THEN
                        sql_text := 
                            sql_text || 
                                'INNER JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = ' || quote_literal(pusuarioid) || ' 
                                    AND ACC.empresaid = EMPL.rutempresa 
                                    AND ACC.lugarpagoid = EMPL.lugarpagoid 
                                    AND ACC.departamentoid = EMPL.departamentoid 
                                    AND ACC.centrocostoid = EMPL.centrocostoid ';
                    END IF;
                END IF;
                IF v_niveles >= 4 THEN
                    sql_text := 
                        sql_text || 
                        'JOIN division DIV ON DIV.empresaid = EMPL.rutempresa 
                            AND DIV.divisionid = EMPL.divisionid 
                            AND DIV.lugarpagoid = EMPL.lugarpagoid 
                            AND DIV.departamentoid = EMPL.departamentoid 
                            AND DIV.centrocostoid = EMPL.centrocostoid ';
                    
                    IF v_niveles = 4 THEN
                        sql_text := 
                            sql_text || 
                                'INNER JOIN g_accesoxusuariodivision AS ADIV ON ADIV.usuarioid = ' || quote_literal(pusuarioid) || ' 
                                    AND ADIV.empresaid = EMPL.rutempresa 
                                    AND ADIV.lugarpagoid = EMPL.lugarpagoid 
                                    AND ADIV.departamentoid = EMPL.departamentoid 
                                    AND ADIV.centrocostoid = EMPL.centrocostoid 
                                    AND ADIV.divisionid = EMPL.divisionid ';
                    END IF;
                END IF;
                IF v_niveles = 5 THEN
                    sql_text := 
                        sql_text || 
                        'JOIN quinto_nivel QN ON QN.empresaid = EMPL.rutempresa 
                            AND QN.quintonivelid = EMPL.quintonivelid 
                            AND QN.lugarpagoid = EMPL.lugarpagoid 
                            AND QN.departamentoid = EMPL.departamentoid 
                            AND QN.centrocostoid = EMPL.centrocostoid 
                            AND QN.divisionid = EMPL.divisionid 
                        INNER JOIN g_accesoxusuarioquintonivel AS AQN ON AQN.usuarioid = ' || quote_literal(pusuarioid) || ' 
                            AND AQN.empresaid = EMPL.rutempresa 
                            AND AQN.lugarpagoid = EMPL.lugarpagoid 
                            AND AQN.departamentoid = EMPL.departamentoid  
                            AND AQN.centrocostoid = EMPL.centrocostoid 
                            AND AQN.divisionid = EMPL.divisionid 
                            AND AQN.quintonivelid = EMPL.quintonivelid ';
                END IF;
    sql_text := 
        sql_text || 
        'JOIN tipogestor TD ON TD.idtipogestor = DOC.tipodocumentoid
        JOIN personas PER ON PER.personaid = EMPL.empleadoid
        WHERE 1=1 ';

    -- filtros
    IF pempresaid IS DISTINCT FROM '0' THEN
        sql_text := sql_text || ' AND EMPL.rutempresa = ' || quote_literal(pempresaid);
    END IF;
    IF v_niveles >= 1 AND plugarpagoid <> '' THEN
        sql_text := sql_text || ' AND EMPL.lugarpagoid = ' || quote_literal(plugarpagoid);
    END IF;
    IF v_niveles >= 2 AND pdepartamentoid <> '' THEN
        sql_text := sql_text || ' AND EMPL.departamentoid = ' || quote_literal(pdepartamentoid);
    END IF;
    IF v_niveles >= 3 AND pcentrocostoid <> '' THEN
        sql_text := sql_text || ' AND EMPL.centrocostoid = ' || quote_literal(pcentrocostoid);
    END IF;
    IF v_niveles >= 4 AND pdivisionid <> '' THEN
        sql_text := sql_text || ' AND EMPL.divisionid = ' || quote_literal(pdivisionid);
    END IF;
    IF v_niveles = 5 AND pquintonivelid <> '' THEN
        sql_text := sql_text || ' AND EMPL.quintonivelid = ' || quote_literal(pquintonivelid);
    END IF;
    IF agrupadorid <> 0 THEN
        sql_text := sql_text || ' AND EXISTS (SELECT 1 FROM agrupadortiposdocumentos_tipos AGT WHERE AGT.tipodocumentoid = DOC.tipodocumentoid AND AGT.agrupadorid = ' || agrupadorid || ')';
    END IF;
    IF ptipodocumentoid <> 0 THEN
        sql_text := sql_text || ' AND DOC.tipodocumentoid = ' || ptipodocumentoid;
    END IF;
    IF pempleadoid <> '' THEN
        sql_text := sql_text || ' AND EMPL.empleadoid = ' || quote_literal(pempleadoid);
    END IF;
    IF pfechadesde IS NOT NULL THEN
        sql_text := sql_text || ' AND DOC.fechadocumento BETWEEN ' || quote_literal(pfechadesde::text || ' 00:00:00') || ' AND ' || quote_literal(pfechahasta::text || ' 23:59:59');
    END IF;
    IF rolid_local = 2 THEN
        sql_text := sql_text || ' AND COALESCE(EMPL.rolid, 2) <> 1';
    END IF;
    IF estado_local = 'A' THEN
        sql_text := sql_text || ' AND COALESCE(EMPL.idestadoempleado, ''A'') <> ''E''';
    END IF;

    -- paginación
    offset_start := (pagina - 1) * decuantos;
    sql_text := 'SELECT * FROM (' || sql_text || ') sub WHERE "rownum" > ' || offset_start || ' AND "rownum" <= ' || (offset_start + decuantos);

    -- ejecutar
    OPEN var_cursor FOR EXECUTE sql_text;
    RETURN var_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_consultageneral_todo(refcursor, integer, text, text, text, text, text, text, integer, integer, text, date, date, text)

-- DROP FUNCTION IF EXISTS public.sp_consultageneral_todo(refcursor, integer, text, text, text, text, text, text, integer, integer, text, date, date, text);

CREATE OR REPLACE FUNCTION public.sp_consultageneral_todo(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pempresaid text,
	p_plugarpagoid text,
	p_pdepartamentoid text,
	p_pcentrocostoid text,
	p_pdivisionid text,
    p_pquintonivelid text,  -- SE AGREGA PARA QUINTO NIVEL
	p_agrupadorid integer,
	p_ptipodocumentoid integer,
	p_pempleadoid text,
	p_pfechadesde date,
	p_pfechahasta date,
	p_pusuarioid text)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_query text := '';
    v_xfechadesde text;
    v_xfechahasta text;
    v_rolid integer;
    v_estado text;
    v_niveles    integer;
BEGIN
    -- Obtener niveles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    IF p_pfechadesde IS NOT NULL THEN
        v_xfechadesde := to_char(p_pfechadesde, 'YYYY-MM-DD') || ' 00:00:00.000';
    END IF;
    IF p_pfechahasta IS NOT NULL THEN
        v_xfechahasta := to_char(p_pfechahasta, 'YYYY-MM-DD') || ' 23:59:59.999';
    END IF;

    SELECT COALESCE(rolid, 2), COALESCE(idestadoempleado, 'A')
    INTO v_rolid, v_estado
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;

    v_query := 'SELECT * FROM (
        SELECT DOC.documentoid, DOC.tipodocumentoid, UPPER(TD.nombre) AS "nombredocumento",
                DOC.empleadoid, COALESCE(PER.nombre, '''') || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''') AS "nombre",
                DOC.empresaid, EMP.razonsocial AS "nombreempresa",
                TO_CHAR(DOC.fechadocumento, ''DD-MM-YYYY'') AS "fechadocumento",
                TO_CHAR(DOC.fechacreacion, ''DD-MM-YYYY'') AS "fechacreacion",
                TO_CHAR(EMPL.fechaingreso, ''DD-MM-YYYY'') AS "fechaingreso",
                TO_CHAR(EMPL.fechatermino, ''DD-MM-YYYY'') AS "fechatermino", ';
            IF v_niveles >= 1 THEN
            v_query := 
                v_query || 'LP.lugarpagoid, UPPER(LP.nombrelugarpago) AS "nombrelugarpago", ';
            END IF;
            IF v_niveles >= 2 THEN
                v_query := 
                    v_query || 'DP.departamentoid, UPPER(DP.nombredepartamento) AS "nombredepartamento", ';
            END IF;
            IF v_niveles >= 3 THEN
                v_query := 
                    v_query || 'CCO.centrocostoid, UPPER(CCO.nombrecentrocosto) AS "nombrecentrocosto", ';
            END IF;
            IF v_niveles >= 4 THEN
                v_query := 
                    v_query || 'DIV.divisionid, UPPER(DIV.nombredivision) AS "nombredivision", ';
            END IF;
            IF v_niveles = 5 THEN
                v_query := 
                    v_query || 'QN.quintonivelid, UPPER(QN.nombrequintonivel) AS "nombrequintonivel", ';
            END IF;
        v_query := 
            v_query ||
                ' ROW_NUMBER() OVER (ORDER BY DOC.fechadocumento) AS "RowNum",
                CASE 
                    WHEN COALESCE(DOC.numerocontrato, 0) > 0 THEN DOC.numerocontrato::text
                    ELSE ''''
                END AS "nrocontrato"
        FROM g_documentosinfo AS DOC
        INNER JOIN g_tiposdocumentosxperfil ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_ptipousuarioid || '
        INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
        INNER JOIN empresas AS EMP ON EMP.rutempresa = EMPL.rutempresa ';
        IF v_niveles >= 1 THEN
            v_query := 
                v_query ||
                'JOIN lugarespago LP ON LP.empresaid = EMPL.rutempresa 
                    AND LP.lugarpagoid = EMPL.lugarpagoid  ';
            IF v_niveles = 1 THEN
                v_query := 
                    v_query ||
                    'INNER JOIN g_accesoxusuariolugarespago AS ALP ON ALP.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                        AND ALP.empresaid = EMPL.rutempresa 
                        AND ALP.lugarpagoid = EMPL.lugarpagoid ';
            END IF;
        END IF;
        IF v_niveles >= 2 THEN
            v_query := 
                v_query ||
                'JOIN departamentos DP ON DP.empresaid = EMPL.rutempresa 
                    AND DP.lugarpagoid = EMPL.lugarpagoid 
                    AND DP.departamentoid = EMPL.departamentoid ';
            IF v_niveles = 2 THEN
                v_query := 
                    v_query ||
                        'INNER JOIN g_accesoxusuariodepartamento AS ADV ON ADV.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                            AND ADV.empresaid = EMPL.rutempresa 
                            AND ADV.lugarpagoid = EMPL.lugarpagoid 
                            AND ADV.departamentoid = EMPL.departamentoid ';
            END IF;
        END IF;
        IF v_niveles >= 3 THEN
            v_query := 
                v_query ||
                'JOIN centroscosto CCO ON  CCO.empresaid = EMPL.rutempresa 
                    AND CCO.centrocostoid = EMPL.centrocostoid 
                    AND CCO.lugarpagoid = EMPL.lugarpagoid 
                    AND CCO.departamentoid = EMPL.departamentoid ';
            IF v_niveles = 3 THEN
                v_query := 
                    v_query || 
                        'INNER JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                            AND ACC.empresaid = EMPL.rutempresa 
                            AND ACC.lugarpagoid = EMPL.lugarpagoid 
                            AND ACC.departamentoid = EMPL.departamentoid 
                            AND ACC.centrocostoid = EMPL.centrocostoid ';
            END IF;
        END IF;
        IF v_niveles >= 4 THEN
            v_query := 
                v_query || 
                'JOIN division DIV ON DIV.empresaid = EMPL.rutempresa 
                    AND DIV.divisionid = EMPL.divisionid 
                    AND DIV.lugarpagoid = EMPL.lugarpagoid 
                    AND DIV.departamentoid = EMPL.departamentoid 
                    AND DIV.centrocostoid = EMPL.centrocostoid ';
            
            IF v_niveles = 4 THEN
                v_query := 
                    v_query || 
                        'INNER JOIN g_accesoxusuariodivision AS ADIV ON ADIV.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                            AND ADIV.empresaid = EMPL.rutempresa 
                            AND ADIV.lugarpagoid = EMPL.lugarpagoid 
                            AND ADIV.departamentoid = EMPL.departamentoid 
                            AND ADIV.centrocostoid = EMPL.centrocostoid 
                            AND ADIV.divisionid = EMPL.divisionid ';
            END IF;
        END IF;
        IF v_niveles = 5 THEN
            v_query := 
                v_query || 
                'JOIN quinto_nivel QN ON QN.empresaid = EMPL.rutempresa 
                    AND QN.quintonivelid = EMPL.quintonivelid 
                    AND QN.lugarpagoid = EMPL.lugarpagoid 
                    AND QN.departamentoid = EMPL.departamentoid 
                    AND QN.centrocostoid = EMPL.centrocostoid 
                    AND QN.divisionid = EMPL.divisionid 
                INNER JOIN g_accesoxusuarioquintonivel AS AQN ON AQN.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                    AND AQN.empresaid = EMPL.rutempresa 
                    AND AQN.lugarpagoid = EMPL.lugarpagoid 
                    AND AQN.departamentoid = EMPL.departamentoid  
                    AND AQN.centrocostoid = EMPL.centrocostoid 
                    AND AQN.divisionid = EMPL.divisionid 
                    AND AQN.quintonivelid = EMPL.quintonivelid ';
        END IF;
        v_query := 
            v_query || '
            INNER JOIN tipogestor AS TD ON TD.idtipogestor = DOC.tipodocumentoid 
            INNER JOIN personas AS PER ON PER.personaid = EMPL.empleadoid 
            WHERE 1=1 ';

    IF p_pempresaid <> '0' THEN
        v_query := v_query || ' AND EMPL.rutempresa = ''' || p_pempresaid || '''';
    END IF;
    IF v_niveles >= 1 AND p_plugarpagoid <> '' THEN
        v_query := v_query || ' AND EMPL.lugarpagoid = ' || quote_literal(p_plugarpagoid);
    END IF;
    IF v_niveles >= 2 AND p_pdepartamentoid <> '' THEN
        v_query := v_query || ' AND EMPL.departamentoid = ' || quote_literal(p_pdepartamentoid);
    END IF;
    IF v_niveles >= 3 AND p_pcentrocostoid <> '' THEN
        v_query := v_query || ' AND EMPL.centrocostoid = ' || quote_literal(p_pcentrocostoid);
    END IF;
    IF v_niveles >= 4 AND p_pdivisionid <> '' THEN
        v_query := v_query || ' AND EMPL.divisionid = ' || quote_literal(p_pdivisionid);
    END IF;
    IF v_niveles = 5 AND p_pquintonivelid <> '' THEN
        v_query := v_query || ' AND EMPL.quintonivelid = ' || quote_literal(p_pquintonivelid);
    END IF;
    IF p_agrupadorid <> 0 THEN
        v_query := v_query || ' AND EXISTS (SELECT 1 FROM agrupadortiposdocumentos_tipos AS AGTP WHERE AGTP.tipodocumentoid = DOC.tipodocumentoid AND AGTP.agrupadorid = ' || p_agrupadorid || ')';
    END IF;
    IF p_ptipodocumentoid <> 0 THEN
        v_query := v_query || ' AND DOC.tipodocumentoid = ' || p_ptipodocumentoid;
    END IF;
    IF p_pempleadoid <> '' THEN
        v_query := v_query || ' AND EMPL.empleadoid = ''' || p_pempleadoid || '''';
    END IF;
    IF p_pfechadesde IS NOT NULL THEN
        v_query := v_query || ' AND DOC.fechadocumento BETWEEN ''' || v_xfechadesde || ''' AND ''' || v_xfechahasta || '''';
    END IF;
    IF v_rolid = 2 THEN
        v_query := v_query || ' AND COALESCE(EMPL.rolid, 2) <> 1';
    END IF;
    IF v_estado = 'A' THEN
        v_query := v_query || ' AND COALESCE(EMPL.idestadoempleado, ''A'') <> ''E''';
    END IF;

    v_query := v_query || ') AS X';

    OPEN p_refcursor FOR EXECUTE v_query;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_consultageneral_total(refcursor, integer, character varying, character varying, character varying, character varying, character varying, character varying, integer, integer, character varying, date, date, character varying, integer, numeric)

-- DROP FUNCTION IF EXISTS public.sp_consultageneral_total(refcursor, integer, character varying, character varying, character varying, character varying, character varying, character varying, integer, integer, character varying, date, date, character varying, integer, numeric);

CREATE OR REPLACE FUNCTION public.sp_consultageneral_total(
    p_refcursor refcursor,
    p_ptipousuarioid integer,
    p_pempresaid character varying,
    p_plugarpagoid character varying,
    p_pdepartamentoid character varying,
    p_pcentrocostoid character varying,
    p_pdivisionid character varying,
    p_pquintonivelid character varying,
    p_agrupadorid integer,
    p_ptipodocumentoid integer,
    p_pempleadoid character varying,
    p_pfechadesde date,
    p_pfechahasta date,
    p_pusuarioid character varying,
    p_pagina integer,
    p_decuantos numeric)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error           INTEGER;
    var_mensaje         VARCHAR(100);
    var_totalreg        DECIMAL(9,2);
    var_vdecimal        DECIMAL(9,2);
    var_total           INTEGER;
    var_totalorig       INTEGER;
    var_rolid           INTEGER;
    var_estado          VARCHAR(1);
    var_trabajadores    INTEGER;
    var_Query           TEXT;
    var_w               INTEGER;
    v_niveles           integer;
BEGIN
    -- Inicializar variables
    var_error := 0;
    var_mensaje := '';
    var_w := 0;

    -- Obtener niveles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- Obtener rol y estado del usuario
    SELECT 
        COALESCE(rolid, 2),
        COALESCE(idEstadoEmpleado, 'A')
    INTO 
        var_rolid,
        var_estado
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;

    -- Construir consulta dinámica
    var_Query := 
        'SELECT COUNT(*) FROM (
            SELECT 
                DOC.documentoid, 
                DOC.tipodocumentoid, 
                DOC.empleadoid, 
                DOC.empresaid, ';
                IF v_niveles >= 1 THEN
                    var_Query := 
                        var_Query || 'LP.lugarpagoid, LP.nombrelugarpago, ';
                END IF;
                IF v_niveles >= 2 THEN
                    var_Query := 
                        var_Query || 'DP.departamentoid, DP.nombredepartamento, ';
                END IF;
                IF v_niveles >= 3 THEN
                    var_Query := 
                        var_Query || 'CCO.centrocostoid, CCO.nombrecentrocosto, ';
                END IF;
                IF v_niveles >= 4 THEN
                    var_Query := 
                        var_Query || 'DIV.divisionid, DIV.nombredivision, ';
                END IF;
                IF v_niveles = 5 THEN
                    var_Query := 
                        var_Query || 'QN.quintonivelid, QN.nombrequintonivel, ';
                END IF;
                var_Query := var_Query || 'TO_CHAR(DOC.fechadocumento, ''DD/MM/YYYY'') AS fechadocumento, 
                TO_CHAR(DOC.fechacreacion, ''DD/MM/YYYY'') AS fechacreacion, 
                TO_CHAR(DOC.fechatermino, ''DD/MM/YYYY'') AS fechatermino, 
                COALESCE(DOC.NumeroContrato, 0) AS nrocontrato
            FROM 
                g_documentosinfo AS DOC
                INNER JOIN g_tiposdocumentosxperfil 
                    ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid 
                    AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_ptipousuarioid || ' 
                INNER JOIN empleados AS EMPL 
                    ON EMPL.empleadoid = DOC.empleadoid  
                INNER JOIN empresas AS EMP 
                    ON EMP.rutempresa = EMPL.rutempresa ';

                IF v_niveles >= 1 THEN
                    var_Query := 
                        var_Query ||
                        'JOIN lugarespago LP ON LP.empresaid = EMPL.rutempresa 
                            AND LP.lugarpagoid = EMPL.lugarpagoid  ';
                    IF v_niveles = 1 THEN
                        var_Query := 
                            var_Query ||
                            'LEFT JOIN g_accesoxusuariolugarespago AS ALP ON ALP.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                                AND ALP.empresaid = EMPL.rutempresa 
                                AND ALP.lugarpagoid = EMPL.lugarpagoid ';
                    END IF;
                END IF;
                IF v_niveles >= 2 THEN
                    var_Query := 
                        var_Query ||
                        'JOIN departamentos DP ON DP.empresaid = EMPL.rutempresa 
                            AND DP.lugarpagoid = EMPL.lugarpagoid 
                            AND DP.departamentoid = EMPL.departamentoid ';
                    IF v_niveles = 2 THEN
                        var_Query := 
                            var_Query ||
                                'LEFT JOIN g_accesoxusuariodepartamento AS ADV ON ADV.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                                    AND ADV.empresaid = EMPL.rutempresa 
                                    AND ADV.lugarpagoid = EMPL.lugarpagoid 
                                    AND ADV.departamentoid = EMPL.departamentoid ';
                    END IF;
                END IF;
                IF v_niveles >= 3 THEN
                    var_Query := 
                        var_Query ||
                        'JOIN centroscosto CCO ON  CCO.empresaid = EMPL.rutempresa 
                            AND CCO.centrocostoid = EMPL.centrocostoid 
                            AND CCO.lugarpagoid = EMPL.lugarpagoid 
                            AND CCO.departamentoid = EMPL.departamentoid ';
                    IF v_niveles = 3 THEN
                        var_Query := 
                            var_Query || 
                                'LEFT JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                                    AND ACC.empresaid = EMPL.rutempresa 
                                    AND ACC.lugarpagoid = EMPL.lugarpagoid 
                                    AND ACC.departamentoid = EMPL.departamentoid 
                                    AND ACC.centrocostoid = EMPL.centrocostoid ';
                    END IF;
                END IF;
                IF v_niveles >= 4 THEN
                    var_Query := 
                        var_Query || 
                        'JOIN division DIV ON DIV.empresaid = EMPL.rutempresa 
                            AND DIV.divisionid = EMPL.divisionid 
                            AND DIV.lugarpagoid = EMPL.lugarpagoid 
                            AND DIV.departamentoid = EMPL.departamentoid 
                            AND DIV.centrocostoid = EMPL.centrocostoid 
                            AND DIV.divisionid = EMPL.divisionid ';
                    IF v_niveles = 4 THEN
                        var_Query := 
                            var_Query || 
                                'LEFT JOIN g_accesoxusuariodivision AS ADIV ON ADIV.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                                    AND ADIV.empresaid = EMPL.rutempresa 
                                    AND ADIV.lugarpagoid = EMPL.lugarpagoid 
                                    AND ADIV.departamentoid = EMPL.departamentoid 
                                    AND ADIV.centrocostoid = EMPL.centrocostoid 
                                    AND ADIV.divisionid = EMPL.divisionid ';
                    END IF;
                END IF;
                IF v_niveles = 5 THEN
                    var_Query := 
                        var_Query || 
                        'JOIN quinto_nivel QN ON QN.empresaid = EMPL.rutempresa 
                            AND QN.quintonivelid = EMPL.quintonivelid 
                            AND QN.lugarpagoid = EMPL.lugarpagoid 
                            AND QN.departamentoid = EMPL.departamentoid 
                            AND QN.centrocostoid = EMPL.centrocostoid 
                            AND QN.divisionid = EMPL.divisionid 
                            AND QN.quintonivelid = EMPL.quintonivelid 
                        LEFT JOIN g_accesoxusuarioquintonivel AS AQN ON AQN.usuarioid = ' || quote_literal(p_pusuarioid) || ' 
                            AND AQN.empresaid = EMPL.rutempresa 
                            AND AQN.lugarpagoid = EMPL.lugarpagoid 
                            AND AQN.departamentoid = EMPL.departamentoid  
                            AND AQN.centrocostoid = EMPL.centrocostoid 
                            AND AQN.divisionid = EMPL.divisionid 
                            AND AQN.quintonivelid = EMPL.quintonivelid ';
                END IF;

                var_Query := var_Query ||
                'INNER JOIN tipogestor AS TD 
                    ON TD.idtipogestor = DOC.tipodocumentoid 
                INNER JOIN personas AS PER 
                    ON PER.personaid = EMPL.empleadoid ';

    -- Agregar JOIN condicional para agrupador
    IF (p_agrupadorid <> 0) THEN
        var_Query := var_Query || 'INNER JOIN agrupadortiposdocumentos_tipos agtp ON agtp.tipodocumentoid = DOC.tipodocumentoid ';
    END IF;

    -- Construir WHERE clauses
    var_w := 0;

    IF (p_pempresaid <> '0') THEN
        var_w := var_w + 1;
        var_Query := var_Query || 'WHERE (EMPL.rutempresa = ' || quote_literal(p_pempresaid) || ') ';
    END IF;

    IF (v_niveles >= 1 AND p_plugarpagoid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.lugarpagoid = ' || quote_literal(p_plugarpagoid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.lugarpagoid = ' || quote_literal(p_plugarpagoid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (v_niveles >= 2 AND p_pdepartamentoid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.departamentoid = ' || quote_literal(p_pdepartamentoid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.departamentoid = ' || quote_literal(p_pdepartamentoid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (v_niveles >= 3 AND p_pcentrocostoid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.centrocostoid = ' || quote_literal(p_pcentrocostoid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.centrocostoid = ' || quote_literal(p_pcentrocostoid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (v_niveles >= 4 AND p_pdivisionid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.divisionid = ' || quote_literal(p_pdivisionid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.divisionid = ' || quote_literal(p_pdivisionid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (v_niveles = 5 AND p_pquintonivelid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.quintonivelid = ' || quote_literal(p_pquintonivelid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.quintonivelid = ' || quote_literal(p_pquintonivelid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (p_agrupadorid <> 0) THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (agtp.agrupadorid = ' || p_agrupadorid || ') ';
        ELSE
            var_Query := var_Query || 'AND (agtp.agrupadorid = ' || p_agrupadorid || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (p_ptipodocumentoid <> 0) THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (DOC.tipodocumentoid = ' || p_ptipodocumentoid || ') ';
        ELSE
            var_Query := var_Query || 'AND (DOC.tipodocumentoid = ' || p_ptipodocumentoid || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (p_pempleadoid <> '') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (EMPL.empleadoid = ' || quote_literal(p_pempleadoid) || ') ';
        ELSE
            var_Query := var_Query || 'AND (EMPL.empleadoid = ' || quote_literal(p_pempleadoid) || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (p_pfechadesde IS NOT NULL) THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE (DOC.fechadocumento BETWEEN ' || quote_literal(p_pfechadesde::text || ' 00:00:00') || ' AND ' || quote_literal(p_pfechahasta::text || ' 23:59:59') || ') ';
        ELSE
            var_Query := var_Query || 'AND (DOC.fechadocumento BETWEEN ' || quote_literal(p_pfechadesde::text || ' 00:00:00') || ' AND ' || quote_literal(p_pfechahasta::text || ' 23:59:59') || ') ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (var_rolid = 2) THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE COALESCE(EMPL.rolid, 2) <> 1 ';
        ELSE
            var_Query := var_Query || 'AND COALESCE(EMPL.rolid, 2) <> 1 ';
        END IF;
        var_w := var_w + 1;
    END IF;

    IF (var_estado = 'A') THEN
        IF (var_w = 0) THEN
            var_Query := var_Query || 'WHERE COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E'' ';
        ELSE
            var_Query := var_Query || 'AND COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E'' ';
        END IF;
    END IF;

    var_Query := var_Query || ') as comosifuerauntabla';

    -- Ejecutar la consulta dinámica
    EXECUTE var_Query INTO var_totalorig;

    -- Calcular paginación
    var_totalreg := var_totalorig::DECIMAL / p_decuantos;
    var_vdecimal := var_totalreg - TRUNC(var_totalreg);

    IF var_vdecimal > 0 THEN
        var_total := TRUNC(var_totalreg) + 1;
    ELSE
        var_total := TRUNC(var_totalreg);
    END IF;

    var_totalreg := TRUNC(var_totalreg * p_decuantos);

    -- Retornar resultado
    OPEN p_refcursor FOR
        SELECT var_total AS total, var_totalreg::INTEGER AS totalreg;

    RETURN p_refcursor;
END;
$BODY$;



-- DROP FUNCTION IF EXISTS public.sp_descargamasiva_consulta_listado(refcursor, integer, numeric, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_descargamasiva_consulta_listado(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos numeric,
	p_pusuarioid character varying,
	p_idproceso integer,
	p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor ALIAS FOR p_refcursor;
    var_pinicio INTEGER;
    var_pfin INTEGER;
    var_sql TEXT;
    v_niveles integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_descargamasiva_consulta_listado - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    var_pinicio := (p_pagina - 1) * p_decuantos + 1;
    var_pfin := p_pagina * p_decuantos;

    -- Construir campos SELECT dinámicamente
    var_sql := '
        WITH DocumentosTabla AS (
            SELECT datos
            FROM descargamasiva_consulta
            WHERE idproceso = ' || p_idproceso || ' AND usuarioid = ''' || p_pusuarioid || ''' AND estado = false
            ORDER BY fila
            LIMIT ' || var_pfin || '
        )
        SELECT 
            CAST(c."iddocumento" AS VARCHAR) || ''|'' || td."nombretipodoc" || ''|'' ||
            p."descripcion" || ''|'' || ce."descripcion" || ''|'' || f."descripcion" || ''|'' ||
            COALESCE(TO_CHAR(cdv."fechadocumento", ''DD/MM/YYYY''), '''') || ''|'' ||
            COALESCE(TO_CHAR(c."fechacreacion", ''DD/MM/YYYY''), '''') || ''|'' ||
            c."rutempresa" || ''|'' || e."razonsocial"';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ' || ''|'' || cdv."lugarpagoid" || ''|'' || lp."nombrelugarpago"';
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || ' || ''|'' || cdv."departamentoid" || ''|'' || dep."nombredepartamento"';
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || ' || ''|'' || cdv."centrocosto" || ''|'' || cc."nombrecentrocosto"';
        RAISE NOTICE 'Agregando campo nivel 3: centrocosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || ' || ''|'' || cdv."divisionid" || ''|'' || div."nombredivision"';
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || ' || ''|'' || cdv."quintonivelid" || ''|'' || qn."nombrequintonivel"';
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;

    -- Campos finales (siempre al final)
    var_sql := var_sql || ' || ''|'' || cdv."rut" || ''|'' || 
        COALESCE(per."nombre", '''') || '' '' || COALESCE(per."appaterno", '''') || '' '' || COALESCE(per."apmaterno", '''')';

    -- Construir FROM y JOINs base
    var_sql := var_sql || '
        FROM DocumentosTabla dt
        JOIN contratos c ON dt.datos::INTEGER = c."iddocumento"
        JOIN contratodatosvariables cdv ON c."iddocumento" = cdv."iddocumento"
        LEFT JOIN plantillas pl ON c."idplantilla" = pl."idplantilla"
        LEFT JOIN procesos p ON c."idproceso" = p."idproceso"
        LEFT JOIN contratosestados ce ON c."idestado" = ce."idestado"
        LEFT JOIN firmastipos f ON c."idtipofirma" = f."idtipofirma"
        LEFT JOIN empresas e ON c."rutempresa" = e."rutempresa"
        LEFT JOIN personas per ON cdv."rut" = per."personaid"';

    -- Agregar JOINs de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        LEFT JOIN lugarespago lp ON lp."lugarpagoid" = cdv."lugarpagoid" 
            AND lp."empresaid" = c."rutempresa"';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        LEFT JOIN departamentos dep ON dep."lugarpagoid" = cdv."lugarpagoid" 
            AND dep."departamentoid" = cdv."departamentoid" 
            AND dep."empresaid" = c."rutempresa"';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        LEFT JOIN centroscosto cc ON cc."centrocostoid" = cdv."centrocosto" 
            AND cc."lugarpagoid" = cdv."lugarpagoid" 
            AND cc."departamentoid" = cdv."departamentoid" 
            AND cc."empresaid" = c."rutempresa"';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        LEFT JOIN division div ON div."divisionid" = cdv."divisionid" 
            AND div."lugarpagoid" = cdv."lugarpagoid" 
            AND div."departamentoid" = cdv."departamentoid" 
            AND div."centrocostoid" = cdv."centrocosto" 
            AND div."empresaid" = c."rutempresa"';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel qn ON qn."quintonivelid" = cdv."quintonivelid" 
            AND qn."lugarpagoid" = cdv."lugarpagoid" 
            AND qn."departamentoid" = cdv."departamentoid" 
            AND qn."centrocostoid" = cdv."centrocosto" 
            AND qn."divisionid" = cdv."divisionid" 
            AND qn."empresaid" = c."rutempresa"';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Agregar permisos dinámicos según nivel más alto disponible
    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago alp ON alp."empresaid" = c."rutempresa"
            AND alp."lugarpagoid" = cdv."lugarpagoid"
            AND alp."usuarioid" = ''' || p_pusuarioid || '''';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos adv ON adv."empresaid" = c."rutempresa"
            AND adv."lugarpagoid" = cdv."lugarpagoid"
            AND adv."departamentoid" = cdv."departamentoid"
            AND adv."usuarioid" = ''' || p_pusuarioid || '''';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto acc ON acc."empresaid" = c."rutempresa"
            AND acc."lugarpagoid" = cdv."lugarpagoid"
            AND acc."departamentoid" = cdv."departamentoid"
            AND acc."centrocostoid" = cdv."centrocosto"
            AND acc."usuarioid" = ''' || p_pusuarioid || '''';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision adiv ON adiv."empresaid" = c."rutempresa"
            AND adiv."lugarpagoid" = cdv."lugarpagoid"
            AND adiv."departamentoid" = cdv."departamentoid"
            AND adiv."centrocostoid" = cdv."centrocosto"
            AND adiv."divisionid" = cdv."divisionid"
            AND adiv."usuarioid" = ''' || p_pusuarioid || '''';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel aqn ON aqn."empresaid" = c."rutempresa"
            AND aqn."lugarpagoid" = cdv."lugarpagoid"
            AND aqn."departamentoid" = cdv."departamentoid"
            AND aqn."centrocostoid" = cdv."centrocosto"
            AND aqn."divisionid" = cdv."divisionid"
            AND aqn."quintonivelid" = cdv."quintonivelid"
            AND aqn."usuarioid" = ''' || p_pusuarioid || '''';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Agregar JOINs adicionales existentes
    var_sql := var_sql || '
        LEFT JOIN contratofirmantes cf ON cf."iddocumento" = c."iddocumento" AND cf."rutempresa" = c."rutempresa" AND c."idestado" = cf."idestado"
        LEFT JOIN personas rep ON rep."personaid" = cf."rutfirmante"
        LEFT JOIN contratofirmantes cf_emp ON cf_emp."iddocumento" = c."iddocumento" AND cf_emp."idestado" = 3
        LEFT JOIN contratofirmantes cf_rep ON cf_rep."iddocumento" = c."iddocumento" AND cf_rep."idestado" = 2
        LEFT JOIN tipodocumentos td ON pl."idtipodoc" = td."idtipodoc"
        ORDER BY c."iddocumento" DESC';

    -- Log de la consulta SQL final
    IF p_debug = 1 THEN
        RAISE NOTICE 'Consulta SQL final construida (primeros 500 caracteres): %', LEFT(var_sql, 500);
    END IF;

    -- Ejecutar consulta
    OPEN var_cursor FOR EXECUTE var_sql;

    -- Marcar como consultados los documentos
    UPDATE descargamasiva_consulta
    SET estado = true
    WHERE ctid IN (
        SELECT ctid
        FROM descargamasiva_consulta
        WHERE idproceso = p_idproceso
          AND usuarioid = p_pusuarioid
          AND estado = false
        ORDER BY fila
        LIMIT var_pfin
    );

    RETURN var_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_documentosvigentes_listadoportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_listadoportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_listadoportiempo(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	-- p_pidproceso integer, 
	p_pidplantilla integer, ---------------------------------------
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_pempleado character varying,
	p_prutempleado character varying,
	p_pusuarioid character varying,
	p_pfichaid integer,
	p_fechainicio date,
	p_fechafin date,
    p_fechainiciodocumento date,
	p_fechafindocumento date,
	p_prutempresa_input character varying,
    p_prutempresa character varying,
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
    v_offset integer := (p_pagina - 1) * p_decuantos::integer;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Construir campos SELECT dinámicamente
    var_sql := '
        SELECT
            C.iddocumento        AS "idDocumento",
            PL.idplantilla       AS "idPlantilla",
            PL.Descripcion_Pl    AS "Plantilla",
            PL.idtipodoc         AS "idTipoDoc",
            TD.nombretipodoc     AS "NombreTipoDoc",
            FD.fichaid           AS "fichaid",
            C.idproceso          AS "idProceso", ---------------------------------------
            P.descripcion        AS "Proceso", ---------------------------------------
            C.idestado           AS "idEstado",
            C.idestado           AS "idEstadoDocumento",
            CE.descripcion       AS "Estado",
            C.idtipofirma        AS "idTipoFirma",
            FT.descripcion       AS "Firma",
            C.idwf               AS "idWF",
            WEP.diasmax          AS "DiasEstadoActual",
            to_char(C.fechacreacion, ''DD-MM-YYYY'')    AS "FechaCreacion",
            to_char(C.fechaultimafirma, ''DD-MM-YYYY'') AS "FechaUltimaFirma",
            ROW_NUMBER() OVER (ORDER BY C.iddocumento DESC) AS "RowNum",
            C.rutempresa         AS "RutEmpresa",
            E.razonsocial        AS "RazonSocial",
            CDV.rut              AS "Rut",
            PER.nombre           AS "nombre",
            PER.appaterno        AS "appaterno",
            PER.apmaterno        AS "apmaterno",
            (PER.nombre || '' '' || COALESCE(PER.appaterno,'''') || '' '' || COALESCE(PER.apmaterno,'''')) AS "NombreEmpleado",
            REP.personaid        AS "RutRep",
            REP.nombre           AS "nombre_rep",
            REP.appaterno        AS "appaterno_rep",
            REP.apmaterno        AS "apmaterno_rep",
            (REP.nombre || '' '' || COALESCE(REP.appaterno,'''') || '' '' || COALESCE(REP.apmaterno,'''')) AS "NombreFirmante",
            to_char(CDV.fechadocumento, ''DD-MM-YYYY'')   AS "FechaDocumento"';
    
    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
            CDV.lugarpagoid      AS "LugarPagoid",
            LP.nombrelugarpago   AS "nombrelugarpago"';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
            CDV.departamentoid   AS "departamentoid",
            DEP.nombredepartamento AS "nombredepartamento"';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
            CDV.centrocosto      AS "centrocostoid",
            CC.nombrecentrocosto AS "nombrecentrocosto"';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
            CDV.divisionid       AS "divisionid",
            DIV.nombredivision   AS "nombredivision"';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
            CDV.quintonivelid    AS "quintonivelid",
            QN.nombrequintonivel AS "nombrequintonivel"';
    END IF;
    
    -- Construir FROM y JOINs base
    var_sql := var_sql || '
        FROM contratos C
        JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento
        JOIN personas PER ON PER.personaid = CDV.rut
        JOIN empresas E ON E.rutempresa = C.rutempresa
        LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND C.idestado = CF.idestado
        LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante
        JOIN plantillas PL ON PL.idplantilla = C.idplantilla -------------
        JOIN tipodocumentos TD ON PL.idtipodoc = TD.idtipodoc
        JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc AND T.tipousuarioid = ' || p_ptipousuarioid || '
        JOIN procesos P ON C.idproceso = P.idproceso ---------------------------------------
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
    
    -- IF p_pidproceso != 0 THEN
    --     var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso; 
    -- END IF;

    IF p_pidplantilla != 0 THEN
        var_sql := var_sql || ' AND C.idplantilla = ' || p_pidplantilla; ---------------------------------////////////
    END IF;
    
    IF p_pfichaid > 0 THEN
        var_sql := var_sql || ' AND FD.fichaid = ' || p_pfichaid;
    END IF;
    
    IF p_prutempresa != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ''' || p_prutempresa || '''';
    END IF;

    IF p_prutempresa_input != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ''' || p_prutempresa_input || '''';
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

    --to_char(CDV.fechadocumento, ''DD-MM-YYYY'')   AS "FechaDocumento"'
    IF p_fechainiciodocumento IS NOT NULL OR p_fechafindocumento IS NOT NULL THEN
        IF p_fechainiciodocumento IS NOT NULL AND p_fechafindocumento IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento BETWEEN ''' || p_fechainiciodocumento::text || ''' AND ''' || p_fechafindocumento::text || '''';
        ELSIF p_fechainicio IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento >= ''' || p_fechainiciodocumento::text || '''';
        ELSIF p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento <= ''' || p_fechafindocumento::text || '''';
        END IF;
    END IF;

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
    
    -- Agregar ORDER BY y paginación
    var_sql := var_sql || '
        ORDER BY C.iddocumento DESC
        OFFSET ' || v_offset || ' LIMIT ' || p_decuantos::integer;
        -- Debug: Mostrar SQL generado
    RAISE NOTICE 'SQL generado: %', var_sql;
    -- Ejecutar consulta dinámica
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS error, SQLERRM AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_documentosvigentes_totalportiempo(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, integer, date, date, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)



CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_totalportiempo(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	-- p_pidproceso integer,
	p_pidplantilla integer, ---------------------------------------
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_pempleado character varying,
	p_prutempleado character varying,
	p_pusuarioid character varying,
	p_pfichaid integer,
	p_fechainicio date,
	p_fechafin date,
    p_fechainiciodocumento date,
    p_fechafindocumento date,
    p_prutempresa_input character varying,
	p_prutempresa character varying,
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
    
    -- IF p_pidproceso != 0 THEN
    --     var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso;
    -- END IF;

    IF p_pidplantilla != 0 THEN
        var_sql := var_sql || ' AND C.idplantilla = ' || p_pidplantilla; ---------------------------------////////////
    END IF;

    IF p_pfichaid > 0 THEN
        var_sql := var_sql || ' AND FD.fichaid = ' || p_pfichaid;
    END IF;
    
    IF p_prutempresa != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ''' || p_prutempresa || '''';
    END IF;

    IF p_prutempresa_input != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ''' || p_prutempresa_input || '''';
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

    ---- Agregar filtros de fecha de documento condicionalmente
    IF p_fechainiciodocumento IS NOT NULL OR p_fechafindocumento IS NOT NULL THEN
        IF p_fechainiciodocumento IS NOT NULL AND p_fechafindocumento    IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento BETWEEN ''' || p_fechainiciodocumento::text || ''' AND ''' || p_fechafindocumento::text || '''';
        ELSIF p_fechainiciodocumento IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento >= ''' || p_fechainiciodocumento::text || '''';
        ELSIF p_fechafindocumento IS NOT NULL THEN
            var_sql := var_sql || ' AND CDV.fechadocumento <= ''' || p_fechafindocumento::text || '''';
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
-- FUNCTION: public.sp_g_accesoxusuarioccosto_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuarioccosto_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuarioccosto_x_usuario(
	p_refcursor refcursor,
	pusuarioid character varying,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocosto character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike character varying;
BEGIN
    -- Construir el patrón para la búsqueda: se usa UPPER y TRIM para imitar UPPER(RTRIM(...))
    v_nombrelike := '%' || upper(trim(pcentrocosto)) || '%';
    
    OPEN p_refcursor FOR
        SELECT 
            g_accesoxusuarioccosto.usuarioid,
            g_accesoxusuarioccosto.empresaid,
			g_accesoxusuarioccosto.lugarpagoid,
			g_accesoxusuarioccosto.departamentoid,
            g_accesoxusuarioccosto.centrocostoid,
            upper(centroscosto.nombrecentrocosto) AS "nombrecentrocosto"
        FROM g_accesoxusuarioccosto
        LEFT JOIN centroscosto 
            ON g_accesoxusuarioccosto.centrocostoid = centroscosto.centrocostoid
            AND g_accesoxusuarioccosto.empresaid = centroscosto.empresaid
        WHERE g_accesoxusuarioccosto.usuarioid = pusuarioid
          AND g_accesoxusuarioccosto.empresaid = pempresaid
		  AND g_accesoxusuarioccosto.lugarpagoid = plugarpagoid
		  AND g_accesoxusuarioccosto.departamentoid = pdepartamentoid
          AND (
               upper(trim(centroscosto.nombrecentrocosto)) LIKE v_nombrelike 
               OR upper(trim(centroscosto.centrocostoid)) LIKE v_nombrelike 
               OR (pcentrocosto = '')
          );
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuariodivision_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuariodivision_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuariodivision_x_usuario(
	p_refcursor refcursor,
	pusuarioid character varying,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocostoid character varying,
	pdivision character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike character varying;
BEGIN
    -- Construir el patrón para la búsqueda: se usa UPPER y TRIM para imitar UPPER(RTRIM(...))
    v_nombrelike := '%' || upper(trim(pdivision)) || '%';
    
    OPEN p_refcursor FOR
        SELECT 
            g_accesoxusuariodivision.usuarioid,
            g_accesoxusuariodivision.empresaid,
            g_accesoxusuariodivision.lugarpagoid,
			g_accesoxusuariodivision.departamentoid,
            g_accesoxusuariodivision.centrocostoid,
            g_accesoxusuariodivision.divisionid,
            upper(division.nombredivision) AS "nombredivision"
        FROM g_accesoxusuariodivision
        LEFT JOIN division 
            ON g_accesoxusuariodivision.divisionid = division.divisionid
            AND g_accesoxusuariodivision.empresaid = division.empresaid
            AND g_accesoxusuariodivision.lugarpagoid = division.lugarpagoid
        WHERE g_accesoxusuariodivision.usuarioid = pusuarioid
          AND g_accesoxusuariodivision.empresaid = pempresaid
          AND g_accesoxusuariodivision.lugarpagoid = plugarpagoid
		  AND g_accesoxusuariodivision.departamentoid = pdepartamentoid
          AND g_accesoxusuariodivision.centrocostoid = pcentrocostoid
          AND (
               upper(trim(division.nombredivision)) LIKE v_nombrelike 
               OR upper(trim(division.divisionid)) LIKE v_nombrelike 
               OR (pdivision = '')
          );
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuarioquintonivel_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuarioquintonivel_x_usuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuarioquintonivel_x_usuario(
	p_refcursor refcursor,
	pusuarioid character varying,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocostoid character varying,
	pdivisionid character varying,
	pquintonivelid character varying,
	pquintonivel character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike character varying;
BEGIN
    -- Construir el patrón para la búsqueda: se usa UPPER y TRIM para imitar UPPER(RTRIM(...))
    v_nombrelike := '%' || upper(trim(pquintonivel)) || '%';
    
    OPEN p_refcursor FOR
        SELECT 
            g_accesoxusuarioquintonivel.usuarioid,
            g_accesoxusuarioquintonivel.empresaid,
            g_accesoxusuarioquintonivel.lugarpagoid,
			g_accesoxusuarioquintonivel.departamentoid,
			g_accesoxusuarioquintonivel.centrocostoid,
            g_accesoxusuarioquintonivel.divisionid,
            g_accesoxusuarioquintonivel.quintonivelid,
            upper(quinto_nivel.nombrequintonivel) AS "nombrequintonivel"
        FROM g_accesoxusuarioquintonivel
        LEFT JOIN quinto_nivel 
            ON g_accesoxusuarioquintonivel.quintonivelid = quinto_nivel.quintonivelid
            AND g_accesoxusuarioquintonivel.empresaid = quinto_nivel.empresaid
            AND g_accesoxusuarioquintonivel.lugarpagoid = quinto_nivel.lugarpagoid
			AND g_accesoxusuarioquintonivel.departamentoid = quinto_nivel.departamentoid
			AND g_accesoxusuarioquintonivel.centrocostoid = quinto_nivel.centrocostoid
            AND g_accesoxusuarioquintonivel.divisionid = quinto_nivel.divisionid
        WHERE g_accesoxusuarioquintonivel.usuarioid = pusuarioid
            AND g_accesoxusuarioquintonivel.empresaid = pempresaid
            AND g_accesoxusuarioquintonivel.lugarpagoid = plugarpagoid
            AND g_accesoxusuarioquintonivel.departamentoid = pdepartamentoid
            AND g_accesoxusuarioquintonivel.centrocostoid = pcentrocostoid
            AND g_accesoxusuarioquintonivel.divisionid = pdivisionid
            AND (
                upper(trim(quinto_nivel.nombrequintonivel)) LIKE v_nombrelike 
                OR upper(trim(quinto_nivel.quintonivelid)) LIKE v_nombrelike 
                OR (pquintonivel = '')
            );
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_registroacciones_agregar(refcursor, character varying, character varying, character varying, integer, character varying)

-- DROP FUNCTION IF EXISTS public.sp_registroacciones_agregar(refcursor, character varying, character varying, character varying, integer, character varying);

CREATE OR REPLACE FUNCTION public.sp_registroacciones_agregar(
	p_refcursor refcursor,
	p_pidusuario character varying,
	p_pip character varying,
	p_popcionid character varying,
	p_paccionid integer,
	p_pid character varying,
	p_observaciones character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_tipousuario integer;
    var_error integer := 0;
    var_lmensaje text := '';
BEGIN
    IF p_pIdUsuario IN ('Gestper', 'BioSign') THEN
        INSERT INTO RegistrosAccionesUsuarios(
            IdUsuario, FechaAccion, IP, OpcionId, Accionid, ID, Tipousuarioid, observaciones
        ) VALUES (
            p_pIdUsuario,
            now(),
            p_pIP,
            p_pOpcionId,
            p_pAccionid,
            p_pID,
            var_tipousuario,
			p_observaciones
        );
    ELSE
        IF EXISTS (SELECT 1 FROM usuarios WHERE usuarioid = p_pIdUsuario) THEN
            SELECT tipousuarioid INTO var_tipousuario FROM usuarios WHERE usuarioid = p_pIdUsuario;

            INSERT INTO RegistrosAccionesUsuarios(
                IdUsuario, FechaAccion, IP, OpcionId, Accionid, ID, Tipousuarioid, observaciones
            ) VALUES (
                p_pIdUsuario,
                now(),
                p_pIP,
                p_pOpcionId,
                p_pAccionid,
                p_pID,
                var_tipousuario,
				p_observaciones
            );
        ELSE
            var_error := 1;
            var_lmensaje := 'El usuario no existe.';
        END IF;
    END IF;

    OPEN p_refcursor FOR SELECT var_error AS "error", var_lmensaje AS "mensaje";
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_registroacciones_listado(refcursor, integer, integer, numeric, integer, character varying, character varying, date, date, integer, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_registroacciones_listado(refcursor, integer, integer, numeric, integer, character varying, character varying, date, date, integer, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_registroacciones_listado(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_pidregistro integer,
	p_pusuarioregistro character varying,
	p_pnombreusuarioregistro character varying,
	p_fechaaccioninicio date,
	p_fechaaccionfin date,
	p_paccionid integer,
	p_pid character varying,
	p_pusuarioid character varying,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_Pinicio integer := (p_pagina - 1) * p_decuantos + 1;
    var_Pfin integer := p_pagina * p_decuantos;
    var_sql text;
    var_xfechadesde timestamp;
    var_xfechahasta timestamp;
BEGIN
    var_sql := '
        SELECT * FROM (
            SELECT 
                RAU.idRegistro AS "idRegistro",
                RAU.IdUsuario AS "idUsuarioRegistro",
                A.Accion AS "Accion",
                COALESCE(P.nombre,'''') || COALESCE(P.appaterno,'''') || COALESCE(P.apmaterno,'''') AS "Nombre",
                RAU.ID AS "ID",
                TO_CHAR(RAU.FechaAccion, ''DD-MM-YYYY'') || '' '' || TO_CHAR(RAU.FechaAccion, ''HH24:MI:SS'') AS "FechaAccion",
                P.nombre AS "nombre",
                P.appaterno AS "appaterno",
                P.apmaterno AS "apmaterno",
				RAU.observaciones as "observaciones",
                ROW_NUMBER() OVER (ORDER BY RAU.idRegistro DESC) AS "linea"
            FROM RegistrosAccionesUsuarios RAU
            INNER JOIN Accion A ON A.accionid = RAU.Accionid
            LEFT JOIN Personas P ON P.personaid = RAU.IdUsuario
            WHERE 1 = 1';

    IF p_pusuarioRegistro <> '' THEN
        var_sql := var_sql || ' AND RAU.IdUsuario ILIKE ' || quote_literal('%' || p_pusuarioRegistro || '%');
    END IF;

    IF p_pnombreusuarioRegistro <> '' THEN
        var_sql := var_sql || ' AND (COALESCE(P.nombre,'''') || COALESCE(P.appaterno,'''') || COALESCE(P.apmaterno,'''')) ILIKE ' || quote_literal('%' || p_pnombreusuarioRegistro || '%');
    END IF;

    IF p_pidRegistro <> 0 THEN
        var_sql := var_sql || ' AND RAU.idRegistro = ' || p_pidRegistro;
    END IF;

    IF p_fechaAccionInicio IS NOT NULL AND p_fechaAccionFin IS NOT NULL THEN
        var_xfechadesde := date_trunc('day', p_fechaAccionInicio);
        var_xfechahasta := p_fechaAccionFin + interval '23 hours 59 minutes 59.99 seconds';
        var_sql := var_sql || ' AND RAU.FechaAccion BETWEEN ' || quote_literal(var_xfechadesde) || ' AND ' || quote_literal(var_xfechahasta);
    ELSIF p_fechaAccionInicio IS NOT NULL AND p_fechaAccionFin IS NULL THEN
        var_xfechadesde := date_trunc('day', p_fechaAccionInicio);
        var_sql := var_sql || ' AND RAU.FechaAccion >= ' || quote_literal(var_xfechadesde);
    ELSIF p_fechaAccionInicio IS NULL AND p_fechaAccionFin IS NOT NULL THEN
        var_xfechahasta := p_fechaAccionFin + interval '23 hours 59 minutes 59.99 seconds';
        var_sql := var_sql || ' AND RAU.FechaAccion <= ' || quote_literal(var_xfechahasta);
    END IF;

    IF p_pAccionid <> 0 THEN
        var_sql := var_sql || ' AND RAU.Accionid = ' || p_pAccionid;
    END IF;

    IF p_pID <> '' THEN
        var_sql := var_sql || ' AND RAU.ID = ' || quote_literal(p_pID);
    END IF;

    var_sql := var_sql || ') sub WHERE "linea" BETWEEN ' || var_Pinicio || ' AND ' || var_Pfin || ';';

    IF p_debug = 1 THEN
        RAISE NOTICE '%', var_sql;
    END IF;

    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


