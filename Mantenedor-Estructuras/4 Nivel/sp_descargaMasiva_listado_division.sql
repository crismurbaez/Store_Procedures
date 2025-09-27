-- FUNCTION: public.sp_descargaMasiva_listado_division(refcursor, integer, numeric, character varying, integer, smallint)
-- Descarga masiva de divisiones con paginación y control de estado

-- DROP FUNCTION IF EXISTS public.sp_descargaMasiva_listado_division(refcursor, integer, numeric, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_descargaMasiva_listado_division(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos numeric,
	p_pusuarioid character varying,
	p_idproceso integer,
	p_debug smallint DEFAULT 0
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor ALIAS FOR p_refcursor;
    var_pinicio INTEGER;
    var_pfin INTEGER;
BEGIN
    -- Cálculo de rangos para paginación
    var_pinicio := (p_pagina - 1) * p_decuantos + 1;
    var_pfin := p_pagina * p_decuantos;

    -- DEBUG
    IF p_debug = 1 THEN
        RAISE NOTICE 'DescargaMasiva Divisiones: pagina=%, decuantos=%, usuarioid=%, idproceso=%',
            p_pagina, p_decuantos, p_pusuarioid, p_idproceso;
    END IF;

    -- Abrimos el cursor con los resultados
    OPEN var_cursor FOR
    WITH DocumentosTabla AS (
        SELECT Datos
        FROM DescargaMasiva_Consulta
        WHERE idProceso = p_idproceso
          AND usuarioid = p_pusuarioid
          AND estado = false
        ORDER BY fila
        LIMIT p_decuantos OFFSET var_pinicio - 1
    )
    SELECT
        EM.razonsocial || '|' || 
        LP.lugarpagoid || '|' || LP.nombrelugarpago || '|' ||
        DP.departamentoid || '|' || DP.nombredepartamento || '|' ||
        CC.centrocostoid || '|' || CC.nombrecentrocosto || '|' ||
        D.divisionid || '|' || D.nombredivision || '|' ||
        COALESCE(D.direccion, '') || '|' ||
        COALESCE(D.comuna, '') || '|' ||
        COALESCE(D.ciudad, '') AS "resultado"
    FROM DocumentosTabla DT
    INNER JOIN division D ON DT.Datos = D.divisionid
    INNER JOIN centroscosto CC ON D.centrocostoid = CC.centrocostoid 
                                 AND D.departamentoid = CC.departamentoid 
                                 AND D.lugarpagoid = CC.lugarpagoid 
                                 AND D.empresaid = CC.empresaid
    INNER JOIN departamentos DP ON D.departamentoid = DP.departamentoid 
                                   AND D.lugarpagoid = DP.lugarpagoid 
                                   AND D.empresaid = DP.empresaid
    INNER JOIN lugarespago LP ON D.lugarpagoid = LP.lugarpagoid 
                              AND D.empresaid = LP.empresaid
    INNER JOIN empresas EM ON D.empresaid = EM.rutempresa
    GROUP BY EM.razonsocial, LP.lugarpagoid, LP.nombrelugarpago, 
             DP.departamentoid, DP.nombredepartamento, 
             CC.centrocostoid, CC.nombrecentrocosto,
             D.divisionid, D.nombredivision, D.direccion, D.comuna, D.ciudad
    ORDER BY D.nombredivision ASC;

    -- Actualizamos registros ya consultados
    UPDATE DescargaMasiva_Consulta
    SET estado = true
    WHERE idProceso = p_idproceso
      AND usuarioid = p_pusuarioid
      AND estado = false
      AND fila <= var_pfin;

    RETURN var_cursor;
END;
$BODY$;

ALTER FUNCTION public.sp_descargaMasiva_listado_division(refcursor, integer, numeric, character varying, integer, smallint)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_descargaMasiva_listado_division(refcursor, integer, numeric, character varying, integer, smallint)
    IS 'Descarga masiva de divisiones con paginación y control de estado';

