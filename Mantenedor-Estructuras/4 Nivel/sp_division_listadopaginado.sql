-- FUNCTION: public.sp_division_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
-- Listado paginado de divisiones con filtros de búsqueda

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
	p_debug smallint DEFAULT 0
)
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
            d.divisionid as "idDivision",
            d.divisionid as divisionid,
            d.nombredivision,
            d.centrocostoid,
            cc.nombrecentrocosto,
            d.departamentoid,
            dp.nombredepartamento,
            d.lugarpagoid,
            lp.nombrelugarpago,
            d.empresaid,
            d.empresaid as "RutEmpresa",
            e.razonsocial,
            ROW_NUMBER() OVER (ORDER BY d.nombredivision) AS RowNum
        FROM division d
        JOIN centroscosto cc ON d.centrocostoid = cc.centrocostoid 
                             AND d.departamentoid = cc.departamentoid 
                             AND d.lugarpagoid = cc.lugarpagoid 
                             AND d.empresaid = cc.empresaid
        JOIN departamentos dp ON d.departamentoid = dp.departamentoid 
                               AND d.lugarpagoid = dp.lugarpagoid 
                               AND d.empresaid = dp.empresaid
        JOIN lugarespago lp ON d.lugarpagoid = lp.lugarpagoid 
                            AND d.empresaid = lp.empresaid
        JOIN empresas e ON d.empresaid = e.rutempresa
        WHERE
            -- Filtro por división (ID exacto o búsqueda por nombre)
            (p_pdivisionid = '' OR p_pdivisionid = '0' 
             OR d.divisionid = p_pdivisionid 
             OR d.nombredivision ILIKE '%' || p_pdivisionid || '%')
        AND 
            -- Filtro por nombre de división
            (p_pnombredivision = '' 
             OR d.nombredivision ILIKE '%' || p_pnombredivision || '%')
        AND 
            -- Filtro por centro de costo (ID exacto o búsqueda por nombre)
            (p_pcentrocostoid = '' OR p_pcentrocostoid = '0' 
             OR d.centrocostoid = p_pcentrocostoid 
             OR cc.nombrecentrocosto ILIKE '%' || p_pcentrocostoid || '%')
        AND 
            -- Filtro por departamento (ID exacto o búsqueda por nombre)
            (p_pdepartamentoid = '' OR p_pdepartamentoid = '0' 
             OR d.departamentoid = p_pdepartamentoid 
             OR dp.nombredepartamento ILIKE '%' || p_pdepartamentoid || '%')
        AND 
            -- Filtro por lugar de pago (ID exacto o búsqueda por nombre)
            (p_plugarpagoid = '' OR p_plugarpagoid = '0' 
             OR d.lugarpagoid = p_plugarpagoid 
             OR lp.nombrelugarpago ILIKE '%' || p_plugarpagoid || '%')
        AND 
            -- Filtro por empresa
            (p_pempresaid = '' OR p_pempresaid = '0' 
             OR d.empresaid = p_pempresaid 
             OR e.razonsocial ILIKE '%' || p_pempresaid || '%')
    )
    SELECT
        "idDivision",
        divisionid,
        nombredivision,
        centrocostoid,
        nombrecentrocosto,
        departamentoid,
        nombredepartamento,
        lugarpagoid,
        nombrelugarpago,
        empresaid,
        "RutEmpresa",
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
