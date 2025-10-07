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
BEGIN
    var_pinicio := (p_pagina - 1) * p_decuantos + 1;
    var_pfin := p_pagina * p_decuantos;

    var_sql := format($fmt$
        WITH DocumentosTabla AS (
            SELECT datos
            FROM descargamasiva_consulta
            WHERE idproceso = %L AND usuarioid = %L AND estado = false
            ORDER BY fila
            LIMIT %s
        )
        SELECT 
            CAST(c."iddocumento" AS VARCHAR) || '|' || td."nombretipodoc" || '|' || p."descripcion" || '|' ||
            ce."descripcion" || '|' || f."descripcion" || '|' ||
            COALESCE(TO_CHAR(cdv."fechadocumento", 'DD/MM/YYYY'), '') || '|' ||
            COALESCE(TO_CHAR(c."fechacreacion", 'DD/MM/YYYY'), '') || '|' ||
            c."rutempresa" || '|' || e."razonsocial" || '|' ||
            cdv."lugarpagoid" || '|' || lp."nombrelugarpago" || '|' ||
            cdv."departamentoid" || '|' || dep."nombredepartamento" ||
--          '|' || cdv."centrocosto" || '|' || cc."nombrecentrocosto" ||
--          '|' || cdv."divisionid" || '|' || dv."nombredivision" ||
            '|' || cdv."rut" || '|' || 
            COALESCE(per."nombre", '') || ' ' || COALESCE(per."appaterno", '') || ' ' || COALESCE(per."apmaterno", '')
        FROM DocumentosTabla dt
        JOIN contratos c ON dt.datos::INTEGER = c."iddocumento"
        JOIN contratodatosvariables cdv ON c."iddocumento" = cdv."iddocumento"
        LEFT JOIN plantillas pl ON c."idplantilla" = pl."idplantilla"
        LEFT JOIN procesos p ON c."idproceso" = p."idproceso"
        LEFT JOIN contratosestados ce ON c."idestado" = ce."idestado"
        LEFT JOIN firmastipos f ON c."idtipofirma" = f."idtipofirma"
        LEFT JOIN empresas e ON c."rutempresa" = e."rutempresa"
        LEFT JOIN personas per ON cdv."rut" = per."personaid"
        LEFT JOIN departamentos dep ON dep."lugarpagoid" = cdv."lugarpagoid" AND dep."departamentoid" = cdv."departamentoid" AND dep."empresaid" = c."rutempresa"
--      LEFT JOIN centroscosto cc ON cc."centrocostoid" = cdv."centrocosto" AND cc."lugarpagoid" = cdv."lugarpagoid" AND cc."departamentoid" = cdv."departamentoid" AND cc."empresaid" = c."rutempresa"
        LEFT JOIN lugarespago lp ON lp."lugarpagoid" = cdv."lugarpagoid" AND lp."empresaid" = c."rutempresa"
--      LEFT JOIN division dv ON dv."centrocostoid" = cdv."centrocosto" AND dv."lugarpagoid" = cdv."lugarpagoid" AND dv."departamentoid" = cdv."departamentoid" AND dv."empresaid" = c."rutempresa" AND dv."divisionid" = cdv."divisionid"
        LEFT JOIN contratofirmantes cf ON cf."iddocumento" = c."iddocumento" AND cf."rutempresa" = c."rutempresa" AND c."idestado" = cf."idestado"
        LEFT JOIN personas rep ON rep."personaid" = cf."rutfirmante"
        LEFT JOIN contratofirmantes cf_emp ON cf_emp."iddocumento" = c."iddocumento" AND cf_emp."idestado" = 3
        LEFT JOIN contratofirmantes cf_rep ON cf_rep."iddocumento" = c."iddocumento" AND cf_rep."idestado" = 2
        LEFT JOIN tipodocumentos td ON pl."idtipodoc" = td."idtipodoc"
        ORDER BY c."iddocumento" DESC
    $fmt$, p_idproceso, p_pusuarioid, var_pfin);

    IF p_debug = 1 THEN
        RAISE NOTICE 'Consulta generada: %', var_sql;
    END IF;

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
