-- FUNCTION: public.sp_division_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_division_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_division_listadopaginado(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos integer,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying,
	p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_Pinicio int := (p_pagina - 1) * p_decuantos + 1;
    var_Pfin    int := p_pagina * p_decuantos;
BEGIN
    IF p_debug = 1 THEN
        RAISE NOTICE 'ListadoPaginado: pagina=%, decuantos=%, divisionid=%, nombre=%, centrocosto=%, departamento=%, lugarpago=%, empresa=%',
            p_pagina, p_decuantos, p_pdivisionid, p_pnombredivision, p_pcentrocostoid,
            p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    OPEN p_refcursor FOR
    WITH DocumentosTabla AS (
        SELECT
            div.divisionid,
            div.nombredivision,
            div.centrocostoid,
            cc.nombrecentrocosto,
            div.departamentoid,
            dp.nombredepartamento,
            div.lugarpagoid,
            lp.nombrelugarpago,
            div.empresaid,
            e.razonsocial,
            ROW_NUMBER() OVER (ORDER BY div.nombredivision) AS RowNum
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
             OR div.divisionid = p_pdivisionid) 
        AND 
            -- Filtro por nombre de división
            (p_pnombredivision = '' 
             OR div.nombredivision ILIKE '%' || p_pnombredivision || '%')
        AND 
            -- Filtro por centro de costo (ID exacto o búsqueda por nombre)
            (p_pcentrocostoid = '' OR p_pcentrocostoid = '0' 
             OR div.centrocostoid = p_pcentrocostoid) 
        AND 
            -- Filtro por departamento (ID exacto o búsqueda por nombre)
            (p_pdepartamentoid = '' OR p_pdepartamentoid = '0' 
             OR div.departamentoid = p_pdepartamentoid)
        AND 
            -- Filtro por lugar de pago (ID exacto o búsqueda por nombre)
            (p_plugarpagoid = '' OR p_plugarpagoid = '0' 
             OR div.lugarpagoid = p_plugarpagoid)
        AND 
            -- Filtro por empresa
            (p_pempresaid = '' OR p_pempresaid = '0' 
             OR div.empresaid = p_pempresaid 
             OR e.razonsocial ILIKE '%' || p_pempresaid || '%')
    )
    SELECT
        divisionid,
        nombredivision,
        centrocostoid,
        nombrecentrocosto,
        departamentoid,
        nombredepartamento,
        lugarpagoid,
        nombrelugarpago,
        empresaid,
        empresaid AS "RutEmpresa",
        razonsocial,
        RowNum
    FROM DocumentosTabla
    WHERE RowNum BETWEEN var_Pinicio AND var_Pfin
    ORDER BY divisionid ASC;

    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_division_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_division_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    IS 'Listado paginado de divisiones con filtros de búsqueda';
