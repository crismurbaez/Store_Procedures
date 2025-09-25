-- FUNCTION: public.sp_quintonivel_listado(refcursor, character varying, character varying, character varying, character varying, character varying)
-- Listado simple de quinto nivel por empresa, lugar de pago, departamento, centro de costo y división

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_listado(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_listado(
	p_refcursor refcursor,
	pempresaid character varying,
	plugarpagoid character varying,
	pdepartamentoid character varying,
	pcentrocostoid character varying,
	pdivisionid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            Q.quintonivelid AS "quintonivelid",
            Q.nombrequintonivel AS "nombrequintonivel",
            Q.divisionid AS "divisionid",
            Q.centrocostoid AS "centrocostoid",
            Q.departamentoid AS "departamentoid",
            Q.lugarpagoid AS "lugarpagoid",
            ('''' || Q.quintonivelid || '''') AS "qn"
        FROM 
            quinto_nivel Q
        WHERE 
            Q.empresaid = pempresaid
            AND Q.lugarpagoid = plugarpagoid
            AND Q.departamentoid = pdepartamentoid
            AND Q.centrocostoid = pcentrocostoid
            AND Q.divisionid = pdivisionid
        ORDER BY 
            Q.nombrequintonivel;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_listado(refcursor, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_listado(refcursor, character varying, character varying, character varying, character varying, character varying)
    IS 'Listado simple de quinto nivel por empresa, lugar de pago, departamento, centro de costo y división';
