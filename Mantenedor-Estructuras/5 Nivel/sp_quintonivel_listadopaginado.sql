-- FUNCTION: public.sp_quintonivel_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
-- Listado paginado de quinto nivel con filtros de búsqueda

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_listadopaginado(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos integer,
	p_pquintonivelid character varying,
	p_pnombrequintonivel character varying,
	p_pdivisionid character varying,
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
        RAISE NOTICE 'ListadoPaginado: pagina=%, decuantos=%, quintonivelid=%, nombre=%, division=%, centrocosto=%, departamento=%, lugarpago=%, empresa=%',
            p_pagina, p_decuantos, p_pquintonivelid, p_pnombrequintonivel, p_pdivisionid, p_pcentrocostoid,
            p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    OPEN p_refcursor FOR
    WITH DocumentosTabla AS (
        SELECT
            qn.quintonivelid,
            qn.nombrequintonivel,
            qn.divisionid,
            div.nombredivision,
            qn.centrocostoid,
            cc.nombrecentrocosto,
            qn.departamentoid,
            dp.nombredepartamento,
            qn.lugarpagoid,
            lp.nombrelugarpago,
            qn.empresaid,
            e.razonsocial,
            ROW_NUMBER() OVER (ORDER BY qn.nombrequintonivel) AS RowNum
        FROM quinto_nivel qn
        JOIN division div ON qn.divisionid = div.divisionid 
                          AND qn.centrocostoid = div.centrocostoid 
                          AND qn.departamentoid = div.departamentoid 
                          AND qn.lugarpagoid = div.lugarpagoid 
                          AND qn.empresaid = div.empresaid
        JOIN centroscosto cc ON qn.centrocostoid = cc.centrocostoid 
                             AND qn.departamentoid = cc.departamentoid 
                             AND qn.lugarpagoid = cc.lugarpagoid 
                             AND qn.empresaid = cc.empresaid
        JOIN departamentos dp ON qn.departamentoid = dp.departamentoid 
                               AND qn.lugarpagoid = dp.lugarpagoid 
                               AND qn.empresaid = dp.empresaid
        JOIN lugarespago lp ON qn.lugarpagoid = lp.lugarpagoid 
                            AND qn.empresaid = lp.empresaid
        JOIN empresas e ON qn.empresaid = e.rutempresa
        WHERE
            -- Filtro por quinto nivel (ID exacto o búsqueda por nombre)
            (p_pquintonivelid = '' OR p_pquintonivelid = '0' 
             OR qn.quintonivelid = p_pquintonivelid 
             OR qn.nombrequintonivel ILIKE '%' || p_pquintonivelid || '%')
        AND 
            -- Filtro por nombre de quinto nivel
            (p_pnombrequintonivel = '' 
             OR qn.nombrequintonivel ILIKE '%' || p_pnombrequintonivel || '%')
        AND 
            -- Filtro por división (ID exacto o búsqueda por nombre)
            (p_pdivisionid = '' OR p_pdivisionid = '0' 
             OR qn.divisionid = p_pdivisionid 
             OR div.nombredivision ILIKE '%' || p_pdivisionid || '%')
        AND 
            -- Filtro por centro de costo (ID exacto o búsqueda por nombre)
            (p_pcentrocostoid = '' OR p_pcentrocostoid = '0' 
             OR qn.centrocostoid = p_pcentrocostoid 
             OR cc.nombrecentrocosto ILIKE '%' || p_pcentrocostoid || '%')
        AND 
            -- Filtro por departamento (ID exacto o búsqueda por nombre)
            (p_pdepartamentoid = '' OR p_pdepartamentoid = '0' 
             OR qn.departamentoid = p_pdepartamentoid 
             OR dp.nombredepartamento ILIKE '%' || p_pdepartamentoid || '%')
        AND 
            -- Filtro por lugar de pago (ID exacto o búsqueda por nombre)
            (p_plugarpagoid = '' OR p_plugarpagoid = '0' 
             OR qn.lugarpagoid = p_plugarpagoid 
             OR lp.nombrelugarpago ILIKE '%' || p_plugarpagoid || '%')
        AND 
            -- Filtro por empresa
            (p_pempresaid = '' OR p_pempresaid = '0' 
             OR qn.empresaid = p_pempresaid 
             OR e.razonsocial ILIKE '%' || p_pempresaid || '%')
    )
    SELECT
        quintonivelid,
        nombrequintonivel,
        divisionid,
        nombredivision,
        centrocostoid,
        nombrecentrocosto,
        departamentoid,
        nombredepartamento,
        lugarpagoid,
        nombrelugarpago,
        empresaid,
        empresaid AS RutEmpresa,
        razonsocial,
        RowNum
    FROM DocumentosTabla
    WHERE RowNum BETWEEN var_Pinicio AND var_Pfin
    ORDER BY quintonivelid ASC;

    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint)
    IS 'Listado paginado de quinto nivel con filtros de búsqueda';
