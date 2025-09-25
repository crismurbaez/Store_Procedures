-- FUNCTION: public.sp_centroscosto_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_centroscosto_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_centroscosto_listadopaginado(
	p_refcursor refcursor,
	p_pagina integer,
	p_decuantos integer,
	p_pcentrocostoid character varying,
	p_pnombrecentrocosto character varying,
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
        RAISE NOTICE 'ListadoPaginado: pagina=%, decuantos=%, centrocostoid=%, nombre=%, departamento=%, lugarpago=%, empresa=%',
            p_pagina, p_decuantos, p_pcentrocostoid, p_pnombrecentrocosto, 
            p_pdepartamentoid, p_plugarpagoid, p_pempresaid;
    END IF;

    OPEN p_refcursor FOR
    WITH DocumentosTabla AS (
        SELECT
            cc.centrocostoid as "idCentroCosto",
			cc.centrocostoid as centrocostoid,
            cc.nombrecentrocosto,
            cc.departamentoid,
            dp.nombredepartamento,
            cc.lugarpagoid,
            lp.nombrelugarpago,
            cc.empresaid,
			cc.empresaid as "RutEmpresa",
            e.razonsocial,
            ROW_NUMBER() OVER (ORDER BY cc.nombrecentrocosto) AS RowNum
        FROM centroscosto cc
        JOIN departamentos dp ON cc.departamentoid = dp.departamentoid 
                               AND cc.lugarpagoid = dp.lugarpagoid 
                               AND cc.empresaid = dp.empresaid
        JOIN lugarespago lp ON cc.lugarpagoid = lp.lugarpagoid 
                            AND cc.empresaid = lp.empresaid
        JOIN empresas e ON cc.empresaid = e.rutempresa
        WHERE
            -- Filtro por centro de costo (ID exacto o búsqueda por nombre)
            (p_pcentrocostoid = '' OR p_pcentrocostoid = '0' 
             OR cc.centrocostoid = p_pcentrocostoid 
             OR cc.nombrecentrocosto ILIKE '%' || p_pcentrocostoid || '%')
        AND 
            -- Filtro por nombre de centro de costo
            (p_pnombrecentrocosto = '' 
             OR cc.nombrecentrocosto ILIKE '%' || p_pnombrecentrocosto || '%')
        AND 
            -- Filtro por departamento (ID exacto o búsqueda por nombre)
            (p_pdepartamentoid = '' OR p_pdepartamentoid = '0' 
             OR cc.departamentoid = p_pdepartamentoid 
             OR dp.nombredepartamento ILIKE '%' || p_pdepartamentoid || '%')
        AND 
            -- Filtro por lugar de pago (ID exacto o búsqueda por nombre)
            (p_plugarpagoid = '' OR p_plugarpagoid = '0' 
             OR cc.lugarpagoid = p_plugarpagoid 
             OR lp.nombrelugarpago ILIKE '%' || p_plugarpagoid || '%')
        AND 
            -- Filtro por empresa
            (p_pempresaid = '' OR p_pempresaid = '0' 
             OR cc.empresaid = p_pempresaid 
             OR e.razonsocial ILIKE '%' || p_pempresaid || '%')
    )
    SELECT
		"idCentroCosto",
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
    ORDER BY centrocostoid ASC;

    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_centroscosto_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, smallint)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_centroscosto_listadopaginado(refcursor, integer, integer, character varying, character varying, character varying, character varying, character varying, smallint)
    IS 'Listado paginado de centros de costo con filtros de búsqueda';
