-- FUNCTION: public.sp_niveles_obtener(refcursor)

-- DROP FUNCTION IF EXISTS public.sp_niveles_obtener(refcursor);

CREATE OR REPLACE FUNCTION public.sp_niveles_obtener(
	p_refcursor refcursor
    )
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT := 0;
    v_mensaje TEXT := '';
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            id,
            nombre,
            CASE 
                WHEN activo THEN 1 
                ELSE 0 
            END AS activo,
            nivel
        FROM Niveles_Estructura
        ORDER BY nivel ASC;

    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


