-- FUNCTION: public.sp_division_totalpaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
-- Calcular total de páginas para paginación de divisiones

-- DROP FUNCTION IF EXISTS public.sp_division_totalpaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_division_totalpaginado(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos integer,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying,
	p_debug smallint DEFAULT 0
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_totalorig   bigint;
    var_division    numeric;
    var_remainder   numeric;
    var_totalpages  integer;
BEGIN
    -- DEBUG
    IF p_debug = 1 THEN
        RAISE NOTICE 'TOTALPAGINADO → pagina=%, decuantos=%, divisionid=%, nombre=%, centrocosto=%, departamento=%, lugarpago=%, empresa=%',
            p_pagina, p_decuantos, p_pdivisionid, p_pnombredivision, p_pcentrocostoid,
            p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    -- 1) Conteo total con todos los filtros posibles
    SELECT COUNT(*) 
      INTO var_totalorig
      FROM division div
      JOIN centroscosto cc ON div.centrocostoid = cc.centrocostoid 
                           AND div.departamentoid = cc.departamentoid 
                           AND div.lugarpagoid = cc.lugarpagoid 
                           AND div.empresaid = cc.empresaid
      JOIN departamentos dp ON div.departamentoid = dp.departamentoid 
                             AND div.lugarpagoid = dp.lugarpagoid 
                             AND div.empresaid = dp.empresaid
      JOIN lugarespago lp ON div.lugarpagoid = lp.lugarpagoid 
                          AND div.empresaid = lp.empresaid
      JOIN empresas e ON div.empresaid = e.rutempresa
     WHERE 
       -- Filtro por división (ID exacto o búsqueda por nombre)
       (p_pdivisionid = '' OR p_pdivisionid = '0'
        OR div.divisionid = p_pdivisionid
        OR div.nombredivision ILIKE '%' || p_pdivisionid || '%')
       -- Filtro por nombre de división
       AND (p_pnombredivision = '' 
            OR div.nombredivision ILIKE '%' || p_pnombredivision || '%')
       -- Filtro por centro de costo (ID exacto o búsqueda por nombre)
       AND (p_pcentrocostoid = '' OR p_pcentrocostoid = '0'
            OR div.centrocostoid = p_pcentrocostoid
            OR cc.nombrecentrocosto ILIKE '%' || p_pcentrocostoid || '%')
       -- Filtro por departamento (ID exacto o búsqueda por nombre)
       AND (p_pdepartamentoid = '' OR p_pdepartamentoid = '0'
            OR div.departamentoid = p_pdepartamentoid
            OR dp.nombredepartamento ILIKE '%' || p_pdepartamentoid || '%')
       -- Filtro por lugar de pago (ID exacto o búsqueda por nombre)
       AND (p_plugarpagoid = '' OR p_plugarpagoid = '0'
            OR div.lugarpagoid = p_plugarpagoid
            OR lp.nombrelugarpago ILIKE '%' || p_plugarpagoid || '%')
       -- Filtro por empresa
       AND (p_pempresaid = '' OR p_pempresaid = '0'
            OR div.empresaid = p_pempresaid
            OR e.razonsocial ILIKE '%' || p_pempresaid || '%');

    -- 2) Cálculo de páginas
    var_division  := var_totalorig::numeric / p_decuantos::numeric;
    var_remainder := var_division - floor(var_division);
    IF var_remainder > 0 THEN
        var_totalpages := floor(var_division)::integer + 1;
    ELSE
        var_totalpages := floor(var_division)::integer;
    END IF;

    -- 3) Devolver por cursor sólo los totales
    OPEN p_refcursor FOR
    SELECT
      var_totalpages AS "total",
      var_totalorig  AS "totalreg";

    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_totalpaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_totalpaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    IS 'Calcular total de páginas para paginación de divisiones';
