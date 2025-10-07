-- FUNCTION: public.sp_descargamasiva_consulta_listado(refcursor, integer, numeric, character varying, integer, smallint)

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

ALTER FUNCTION public.sp_descargamasiva_consulta_listado(refcursor, integer, numeric, character varying, integer, smallint)
    OWNER TO postgres;
