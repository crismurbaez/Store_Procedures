-- FUNCTION: public.sp_quintonivel_obtener(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)
-- Obtener un quinto nivel específico

-- DROP FUNCTION IF EXISTS public.sp_quintonivel_obtener(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_quintonivel_obtener(
	p_refcursor refcursor,
	p_pquintonivelid character varying,
	p_pdivisionid character varying,
	p_pcentrocostoid character varying,
	p_pdepartamentoid character varying,
	p_plugarpagoid character varying,
	p_pempresaid character varying
)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            qn.quintonivelid,
            qn.nombrequintonivel,
            qn.empresaid,
            qn.direccion,
            qn.comuna,
            qn.ciudad,
            qn.departamentoid,
            dp.nombredepartamento,
            qn.lugarpagoid,
            lp.nombrelugarpago,
            qn.centrocostoid,
            cc.nombrecentrocosto,
            qn.divisionid,
            div.nombredivision,
            qn.fechacreacion,
            qn.fechamodificacion,
            qn.usuarioid,
            qn.usuarioidmodificacion,
            e.razonsocial AS nombreempresa
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
        WHERE qn.quintonivelid = p_pquintonivelid
          AND qn.divisionid = p_pdivisionid
          AND qn.centrocostoid = p_pcentrocostoid
          AND qn.departamentoid = p_pdepartamentoid
          AND qn.lugarpagoid = p_plugarpagoid
          AND qn.empresaid = p_pempresaid;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

ALTER FUNCTION public.sp_quintonivel_obtener(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)
    OWNER TO postgres;

COMMENT ON FUNCTION public.sp_quintonivel_obtener(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)
    IS 'Obtener un quinto nivel específico con información completa';
