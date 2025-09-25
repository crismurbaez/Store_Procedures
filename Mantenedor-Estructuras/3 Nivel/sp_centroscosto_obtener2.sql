-- FUNCTION: public.sp_centroscosto_obtener2(refcursor, character varying, character varying, character varying, character varying)
-- Obtener un centro de costo específico

-- DROP FUNCTION IF EXISTS public.sp_centroscosto_obtener2(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_centroscosto_obtener2(
	p_refcursor refcursor,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            cc.centrocostoid as centrocostoid,
			cc.centrocostoid as "idCentroCosto",
            cc.nombrecentrocosto,
            cc.empresaid as "empresaid",
			cc.empresaid as "RutEmpresa",
			cc.empresaid as "RazonSocial",
            cc.direccion,
            cc.comuna,
            cc.ciudad,
            cc.departamentoid,
            dp.nombredepartamento,
            cc.lugarpagoid,
            lp.nombrelugarpago,
            cc.fechacreacion,
            cc.fechamodificacion,
            cc.usuarioid,
            cc.usuarioidmodificacion,
            e.razonsocial AS nombreempresa
        FROM centroscosto cc
        JOIN departamentos dp ON cc.departamentoid = dp.departamentoid 
                               AND cc.lugarpagoid = dp.lugarpagoid 
                               AND cc.empresaid = dp.empresaid
        JOIN lugarespago lp ON cc.lugarpagoid = lp.lugarpagoid 
                            AND cc.empresaid = lp.empresaid
        JOIN empresas e ON cc.empresaid = e.rutempresa
        WHERE cc.centrocostoid = p_pcentrocostoid
          AND cc.departamentoid = p_pdepartamentoid
          AND cc.lugarpagoid = p_plugarpagoid
          AND cc.empresaid = p_pempresaid;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_centroscosto_obtener2(refcursor, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_centroscosto_obtener2(refcursor, character varying, character varying, character varying, character varying)
    IS 'Obtener un centro de costo específico con información completa';
