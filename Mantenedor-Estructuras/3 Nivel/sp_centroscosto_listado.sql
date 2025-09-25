-- FUNCTION: public.sp_centroscosto_listado(refcursor, character varying, character varying, character varying)
-- Listado simple de centros de costo por empresa, lugar de pago y departamento

-- DROP FUNCTION IF EXISTS public.sp_centroscosto_listado(refcursor, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_centroscosto_listado(
	p_refcursor refcursor,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            C.centrocostoid AS "centrocostoid",
            C.nombrecentrocosto AS "nombrecentrocosto",
            C.departamentoid AS "departamentoid",
            C.lugarpagoid AS "lugarpagoid",
            ('''' || C.centrocostoid || '''') AS "cc"
        FROM 
            centroscosto C
        WHERE 
            C.empresaid = pempresaid
            AND C.lugarpagoid = plugarpagoid
            AND C.departamentoid = pdepartamentoid
        ORDER BY 
            C.nombrecentrocosto;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_centroscosto_listado(refcursor, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_centroscosto_listado(refcursor, character varying, character varying, character varying)
    IS 'Listado simple de centros de costo por empresa, lugar de pago y departamento';
