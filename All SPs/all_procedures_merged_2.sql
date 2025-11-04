-- FUNCTION: public.sp_accesoxusuario_acctodo_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_acctodo_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_acctodo_centrocosto(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying,
	p_centrocostoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER := 0;
    v_mensaje VARCHAR(100) := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe la relación usuario-empresa, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioempresas
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_usuarioid, p_empresaid);
    END IF;
    
    -- Verificar si existe la relación usuario-lugar de pago, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid);
    END IF;
    
    -- Verificar si existe la relación usuario-departamento, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodepartamentos
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
    ) THEN
        INSERT INTO accesoxusuariodepartamentos (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid);
    END IF;
    
    -- Verificar si existe la relación usuario-centro de costo, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioccosto
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
        AND centrocostoid = p_centrocostoid
    ) THEN
        INSERT INTO accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid, p_centrocostoid);
    END IF;
    
    -- Nivel 4: Insertar permisos para divisiones
    IF v_niveles >= 4 THEN
        INSERT INTO accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        LEFT JOIN accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                 AND ACC.empresaid = p_empresaid
                                                 AND ACC.lugarpagoid = LP.lugarpagoid
                                                 AND ACC.departamentoid = DP.departamentoid
                                                 AND ACC.centrocostoid = CC.centrocostoid
                                                 AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid;
    END IF;
    
    -- Nivel 5: Insertar permisos para quinto nivel
    IF v_niveles >= 5 THEN
        INSERT INTO accesoxusuarioquintonivel (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid, QN.quintonivelid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        INNER JOIN quinto_nivel QN ON CC.lugarpagoid = QN.lugarpagoid 
                                  AND CC.empresaid = QN.empresaid 
                                  AND CC.departamentoid = QN.departamentoid 
                                  AND CC.centrocostoid = QN.centrocostoid
                                  AND DIV.divisionid = QN.divisionid
        LEFT JOIN accesoxusuarioquintonivel AS ACC ON ACC.usuarioid = p_usuarioid
                                                    AND ACC.empresaid = p_empresaid
                                                    AND ACC.lugarpagoid = LP.lugarpagoid
                                                    AND ACC.departamentoid = DP.departamentoid
                                                    AND ACC.centrocostoid = CC.centrocostoid
                                                    AND ACC.divisionid = DIV.divisionid
                                                    AND ACC.quintonivelid = QN.quintonivelid
        WHERE ACC.quintonivelid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid;
    END IF;
    
    -- Retornar resultado
    v_error := 0;
    v_mensaje := '';
    
    -- Abrir cursor con el resultado
    OPEN p_refcursor FOR 
    SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error := 1;
        v_mensaje := 'Error: ' || SQLERRM;
        
        -- Abrir cursor con el error
        OPEN p_refcursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
        
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_accesoxusuario_acctodo_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_acctodo_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_acctodo_division(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying,
	p_centrocostoid character varying,
	p_divisionid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER := 0;
    v_mensaje VARCHAR(100) := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe la relación usuario-empresa, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioempresas
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_usuarioid, p_empresaid);
    END IF;
    
    -- Verificar si existe la relación usuario-lugar de pago, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid);
    END IF;
    
    -- Verificar si existe la relación usuario-departamento, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodepartamentos
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
    ) THEN
        INSERT INTO accesoxusuariodepartamentos (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid);
    END IF;
    
    -- Verificar si existe la relación usuario-centro de costo, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioccosto
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
        AND centrocostoid = p_centrocostoid
    ) THEN
        INSERT INTO accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid, p_centrocostoid);
    END IF;
    
    -- Verificar si existe la relación usuario-división, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodivision
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
        AND centrocostoid = p_centrocostoid
        AND divisionid = p_divisionid
    ) THEN
        INSERT INTO accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid, p_centrocostoid, p_divisionid);
    END IF;
    
    -- Nivel 5: Insertar permisos para quinto nivel
    IF v_niveles >= 5 THEN
        INSERT INTO accesoxusuarioquintonivel (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid, QN.quintonivelid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        INNER JOIN quinto_nivel QN ON CC.lugarpagoid = QN.lugarpagoid 
                                  AND CC.empresaid = QN.empresaid 
                                  AND CC.departamentoid = QN.departamentoid 
                                  AND CC.centrocostoid = QN.centrocostoid
                                  AND DIV.divisionid = QN.divisionid
        LEFT JOIN accesoxusuarioquintonivel AS ACC ON ACC.usuarioid = p_usuarioid
                                                    AND ACC.empresaid = p_empresaid
                                                    AND ACC.lugarpagoid = LP.lugarpagoid
                                                    AND ACC.departamentoid = DP.departamentoid
                                                    AND ACC.centrocostoid = CC.centrocostoid
                                                    AND ACC.divisionid = DIV.divisionid
                                                    AND ACC.quintonivelid = QN.quintonivelid
        WHERE ACC.quintonivelid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid
        AND DIV.divisionid = p_divisionid;
    END IF;
    
    -- Retornar resultado
    v_error := 0;
    v_mensaje := '';
    
    -- Abrir cursor con el resultado
    OPEN p_refcursor FOR 
    SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error := 1;
        v_mensaje := 'Error: ' || SQLERRM;
        
        -- Abrir cursor con el error
        OPEN p_refcursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
        
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_accesoxusuario_elimina_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_elimina_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_centrocosto(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
    v_niveles INTEGER := 0;
BEGIN
    v_error := 0;
    v_mensaje := '';

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- Verificar si existe el registro en centro de costo
    IF EXISTS (
        SELECT usuarioid FROM accesoxusuarioccosto 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuariodivision 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
            ) THEN
                DELETE FROM accesoxusuariodivision 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid;
            END IF;
        END IF;

        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
            ) THEN
                DELETE FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid;
            END IF;
        END IF;

        -- Eliminar el registro principal de centro de costo
        DELETE FROM accesoxusuarioccosto 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid;
    END IF;

    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_error AS error, v_mensaje AS mensaje;

    RETURN var_cursor;

EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_accesoxusuario_elimina_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_elimina_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_division(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying,
	p_pdivisionid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
    v_niveles INTEGER := 0;
BEGIN
    v_error := 0;
    v_mensaje := '';

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- Verificar si existe el registro en división
    IF EXISTS (
        SELECT usuarioid FROM accesoxusuariodivision 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid
    ) THEN
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
                AND divisionid = p_pdivisionid
            ) THEN
                DELETE FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
                AND divisionid = p_pdivisionid;
            END IF;
        END IF;

        -- Eliminar el registro principal de división
        DELETE FROM accesoxusuariodivision 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid;
    END IF;

    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_error AS error, v_mensaje AS mensaje;

    RETURN var_cursor;

EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;


CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_quintonivel(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id de la centrocosto
    p_pdivisionid VARCHAR(14),       -- id de la division
    p_pquintonivelid VARCHAR(14)     -- id del quinto nivel
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    v_error := 0;
    v_mensaje := '';
    -- Eliminar de accesoxusuarioquintonivel si existe
    IF EXISTS (
        SELECT usuarioid FROM accesoxusuarioquintonivel 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid
        AND quintonivelid = p_pquintonivelid
    ) THEN
        DELETE FROM accesoxusuarioquintonivel 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid
        AND quintonivelid = p_pquintonivelid;
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_graba_centrocosto(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14)     -- id del centro de costo
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    v_error := 0;
    v_mensaje := '';
    -- Verificar y insertar en accesoxusuarioempresas si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioempresas
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas
        (usuarioid, empresaid)
        VALUES
        (p_pusuarioid, p_pempresaid);
    END IF;
    -- Verificar y insertar en accesoxusuariolugarespago si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago
        (usuarioid, empresaid, lugarpagoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid);
    END IF;
    -- Verificar y insertar en accesoxusuariodepartamentos si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodepartamentos
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
    ) THEN
        INSERT INTO accesoxusuariodepartamentos
        (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid);
    END IF;
    -- Verificar y insertar en accesoxusuarioccosto si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioccosto
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        INSERT INTO accesoxusuarioccosto
        (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid);
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_graba_division(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id del centro de costo
    p_pdivisioid VARCHAR(14)          -- id del division
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    -- 1. Verificar y insertar en accesoxusuarioempresas si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioempresas
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_pusuarioid, p_pempresaid);
    END IF;
    -- 2. Verificar y insertar en accesoxusuariolugarespago si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid);
    END IF;
    -- 3. Verificar y insertar en accesoxusuariodepartamentos si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodepartamentos
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
    ) THEN
        INSERT INTO accesoxusuariodepartamentos (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid);
    END IF;
    -- 4. Verificar y insertar en accesoxusuarioccosto si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioccosto
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        INSERT INTO accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid);
    END IF;
    -- 5. Verificar y insertar en accesoxusuariodivision si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodivision
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisioid
    ) THEN
        INSERT INTO accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid, p_pdivisioid);
    END IF;
    -- Retornar resultado exitoso
    v_error := 0;
    v_mensaje := '';
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    v_error := 1;
    v_mensaje := SQLERRM;
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_graba_quintonivel(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id del centro de costo
    p_pdivisioid VARCHAR(14),        -- id del division
    p_pquintonivelid VARCHAR(14)     -- id del quinto nivel
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INT;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    v_error := 0;
    v_mensaje := '';
    -- Verificar y insertar en accesoxusuarioempresas si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioempresas
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas
        (usuarioid, empresaid)
        VALUES
        (p_pusuarioid, p_pempresaid);
    END IF;
    -- Verificar y insertar en accesoxusuariolugarespago si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago
        (usuarioid, empresaid, lugarpagoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid);
    END IF;
    -- Verificar y insertar en accesoxusuariodepartamentos si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodepartamentos
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
    ) THEN
        INSERT INTO accesoxusuariodepartamentos
        (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid);
    END IF;
    -- Verificar y insertar en accesoxusuarioccosto si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioccosto
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        INSERT INTO accesoxusuarioccosto
        (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid);
    END IF;
    -- Verificar y insertar en accesoxusuariodivision si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariodivision
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisioid
    ) THEN
        INSERT INTO accesoxusuariodivision
        (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid, p_pdivisioid);
    END IF;
    -- Verificar y insertar en accesoxusuarioquintonivel si no existe
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM accesoxusuarioquintonivel
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisioid
        AND quintonivelid = p_pquintonivelid
    ) THEN
        INSERT INTO accesoxusuarioquintonivel
        (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        VALUES
        (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid, p_pdivisioid, p_pquintonivelid);
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_centroscosto(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocosto VARCHAR(50),      -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos DECIMAL              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    v_inicio INTEGER;
    v_fin INTEGER;
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda
    v_nombrelike := '%' || UPPER(TRIM(p_pcentrocosto)) || '%';
    -- Calcular rangos de paginaciÃ³n
    v_inicio := (p_pagina - 1) * p_decuantos + 1;
    v_fin := p_pagina * p_decuantos;
    -- Abrir cursor con la consulta
    OPEN var_cursor FOR
        SELECT 
            centrocostoid,
            UPPER(nombrecentrocosto) AS nombrecentrocosto,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM accesoxusuarioccosto 
                    WHERE accesoxusuarioccosto.usuarioid = p_pusuarioid 
                    AND accesoxusuarioccosto.empresaid = p_pempresaid
                    AND accesoxusuarioccosto.lugarpagoid = p_plugarpagoid
                    AND accesoxusuarioccosto.departamentoid = p_pdepartamentoid
                    AND accesoxusuarioccosto.centrocostoid = centroscosto.centrocostoid
                )
                THEN 'checked'
                ELSE '' 
            END AS checkconsulta,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM g_accesoxusuarioccosto 
                    WHERE g_accesoxusuarioccosto.usuarioid = p_pusuarioid 
                    AND g_accesoxusuarioccosto.empresaid = p_pempresaid
                    AND g_accesoxusuarioccosto.lugarpagoid = p_plugarpagoid
                    AND g_accesoxusuarioccosto.departamentoid = p_pdepartamentoid
                    AND g_accesoxusuarioccosto.centrocostoid = centroscosto.centrocostoid
                )
                THEN 'checked'
                ELSE '' 
            END AS g_checkconsulta,
            ROW_NUMBER() OVER (ORDER BY centroscosto.centrocostoid) AS rownum
        FROM centroscosto
        WHERE 
            (
                (UPPER(TRIM(centroscosto.nombrecentrocosto)) LIKE v_nombrelike) 
                OR (UPPER(TRIM(centroscosto.centrocostoid)) LIKE v_nombrelike)
                OR (p_pcentrocosto = '')
            )
            AND (departamentoid = p_pdepartamentoid) 
            AND (lugarpagoid = p_plugarpagoid) 
            AND (empresaid = p_pempresaid)
        ORDER BY centroscosto.centrocostoid
        LIMIT p_decuantos OFFSET (p_pagina - 1) * p_decuantos;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_centroscosto_total(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocosto VARCHAR(50),      -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos DECIMAL              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    v_error INT;
    v_mensaje VARCHAR(100);
    v_totalreg DECIMAL(9,2);
    v_vdecimal DECIMAL(9,2);
    v_total INT;
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda (fiel al original)
    v_nombrelike := '%' || UPPER(RTRIM(p_pcentrocosto)) || '%';
    -- Calcular total de registros (fiel al original)
    SELECT (COUNT(*) / p_decuantos) INTO v_totalreg
    FROM (
        SELECT *
        FROM (
            SELECT 
                centroscosto.centrocostoid,
                centroscosto.nombrecentrocosto,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM accesoxusuarioccosto 
                        WHERE accesoxusuarioccosto.usuarioid = p_pusuarioid 
                        AND accesoxusuarioccosto.empresaid = p_pempresaid
                        AND accesoxusuarioccosto.lugarpagoid = p_plugarpagoid
                        AND accesoxusuarioccosto.departamentoid = p_pdepartamentoid
                        AND accesoxusuarioccosto.centrocostoid = centroscosto.centrocostoid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS checkconsulta,
                ROW_NUMBER() OVER (ORDER BY centroscosto.centrocostoid) AS rownum
            FROM centroscosto
            WHERE 
                ((UPPER(RTRIM(centroscosto.nombrecentrocosto)) LIKE v_nombrelike) 
                OR (UPPER(RTRIM(centroscosto.centrocostoid)) LIKE v_nombrelike)
                OR (p_pcentrocosto = ''))
                AND (departamentoid = p_pdepartamentoid) 
                AND (lugarpagoid = p_plugarpagoid) 
                AND (empresaid = p_pempresaid)
        ) ResultadoPaginado
    ) AS comosifuerauntabla;
    -- Calcular decimal y total (fiel al original)
    v_vdecimal := v_totalreg - CAST(v_totalreg AS INTEGER);
    IF v_vdecimal > 0 THEN
        v_total := v_totalreg + 1;
    ELSE
        v_total := v_totalreg;
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_total AS total;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_division(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id centro de costo
    p_pdivision VARCHAR(50),         -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos DECIMAL              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda (fiel al original)
    v_nombrelike := '%' || UPPER(RTRIM(p_pdivision)) || '%';
    -- Abrir cursor con la consulta exacta del original
    OPEN var_cursor FOR
        SELECT *
        FROM (
            SELECT 
                division.divisionid,
                UPPER(division.nombredivision) AS nombredivision,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM accesoxusuariodivision 
                        WHERE accesoxusuariodivision.usuarioid = p_pusuarioid 
                        AND accesoxusuariodivision.empresaid = p_pempresaid
                        AND accesoxusuariodivision.lugarpagoid = p_plugarpagoid
                        AND accesoxusuariodivision.departamentoid = p_pdepartamentoid
                        AND accesoxusuariodivision.centrocostoid = p_pcentrocostoid
                        AND accesoxusuariodivision.divisionid = division.divisionid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS checkconsulta,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM g_accesoxusuariodivision 
                        WHERE g_accesoxusuariodivision.usuarioid = p_pusuarioid 
                        AND g_accesoxusuariodivision.empresaid = p_pempresaid
                        AND g_accesoxusuariodivision.lugarpagoid = p_plugarpagoid
                        AND g_accesoxusuariodivision.departamentoid = p_pdepartamentoid
                        AND g_accesoxusuariodivision.centrocostoid = p_pcentrocostoid
                        AND g_accesoxusuariodivision.divisionid = division.divisionid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS g_checkconsulta,
                ROW_NUMBER() OVER (ORDER BY division.divisionid) AS rownum
            FROM division
            WHERE 
                ((UPPER(RTRIM(division.nombredivision)) LIKE v_nombrelike) 
                OR (UPPER(RTRIM(division.divisionid)) LIKE v_nombrelike)
                OR (p_pdivision = ''))
                AND (centrocostoid = p_pcentrocostoid) 
                AND (departamentoid = p_pdepartamentoid) 
                AND (lugarpagoid = p_plugarpagoid) 
                AND (empresaid = p_pempresaid)
        ) ResultadoPaginado
        WHERE rownum BETWEEN (p_pagina - 1) * p_decuantos + 1 
        AND p_pagina * p_decuantos;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_division_total(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id centro de costo
    p_pdivision VARCHAR(50),         -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos DECIMAL              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    v_error INT;
    v_mensaje VARCHAR(100);
    v_totalreg DECIMAL(9,2);
    v_vdecimal DECIMAL(9,2);
    v_total INT;
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda (fiel al original)
    v_nombrelike := '%' || UPPER(RTRIM(p_pdivision)) || '%';
    -- Calcular total de registros (fiel al original)
    SELECT (COUNT(*) / p_decuantos) INTO v_totalreg
    FROM (
        SELECT *
        FROM (
            SELECT 
                division.divisionid,
                UPPER(division.nombredivision) AS nombredivision,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM accesoxusuariodivision 
                        WHERE accesoxusuariodivision.usuarioid = p_pusuarioid 
                        AND accesoxusuariodivision.empresaid = p_pempresaid
                        AND accesoxusuariodivision.lugarpagoid = p_plugarpagoid
                        AND accesoxusuariodivision.departamentoid = p_pdepartamentoid
                        AND accesoxusuariodivision.centrocostoid = p_pcentrocostoid
                        AND accesoxusuariodivision.divisionid = division.divisionid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS checkconsulta,
                ROW_NUMBER() OVER (ORDER BY division.divisionid) AS rownum
            FROM division
            WHERE 
                ((UPPER(RTRIM(division.nombredivision)) LIKE v_nombrelike) 
                OR (UPPER(RTRIM(division.divisionid)) LIKE v_nombrelike)
                OR (p_pdivision = ''))
                AND (centrocostoid = p_pcentrocostoid) 
                AND (departamentoid = p_pdepartamentoid) 
                AND (lugarpagoid = p_plugarpagoid) 
                AND (empresaid = p_pempresaid)
        ) ResultadoPaginado
    ) AS comosifuerauntabla;
    -- Calcular decimal y total (fiel al original)
    v_vdecimal := v_totalreg - CAST(v_totalreg AS INTEGER);
    IF v_vdecimal > 0 THEN
        v_total := v_totalreg + 1;
    ELSE
        v_total := v_totalreg;
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_total AS total;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_quintonivel(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id centro de costo
    p_pdivisionid VARCHAR(14),       -- id division
    p_pquintonivel VARCHAR(50),      -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos INTEGER              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda (fiel al original)
    v_nombrelike := '%' || UPPER(RTRIM(p_pquintonivel)) || '%';
    -- Abrir cursor con la consulta exacta del original
    OPEN var_cursor FOR
        SELECT *
        FROM (
            SELECT 
                quinto_nivel.quintonivelid,
                UPPER(quinto_nivel.nombrequintonivel) AS nombrequintonivel,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM accesoxusuarioquintonivel 
                        WHERE accesoxusuarioquintonivel.usuarioid = p_pusuarioid 
                        AND accesoxusuarioquintonivel.empresaid = p_pempresaid
                        AND accesoxusuarioquintonivel.lugarpagoid = p_plugarpagoid
                        AND accesoxusuarioquintonivel.departamentoid = p_pdepartamentoid
                        AND accesoxusuarioquintonivel.centrocostoid = p_pcentrocostoid
                        AND accesoxusuarioquintonivel.divisionid = p_pdivisionid
                        AND accesoxusuarioquintonivel.quintonivelid = quinto_nivel.quintonivelid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS checkconsulta,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM g_accesoxusuarioquintonivel 
                        WHERE g_accesoxusuarioquintonivel.usuarioid = p_pusuarioid 
                        AND g_accesoxusuarioquintonivel.empresaid = p_pempresaid
                        AND g_accesoxusuarioquintonivel.lugarpagoid = p_plugarpagoid
                        AND g_accesoxusuarioquintonivel.departamentoid = p_pdepartamentoid
                        AND g_accesoxusuarioquintonivel.centrocostoid = p_pcentrocostoid
                        AND g_accesoxusuarioquintonivel.divisionid = p_pdivisionid
                        AND g_accesoxusuarioquintonivel.quintonivelid = quinto_nivel.quintonivelid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS g_checkconsulta,
                ROW_NUMBER() OVER (ORDER BY quinto_nivel.quintonivelid) AS rownum
            FROM quinto_nivel
            WHERE 
                ((UPPER(RTRIM(quinto_nivel.nombrequintonivel)) LIKE v_nombrelike) 
                OR (UPPER(RTRIM(quinto_nivel.quintonivelid)) LIKE v_nombrelike)
                OR (p_pquintonivel = ''))
                AND (divisionid = p_pdivisionid) 
                AND (centrocostoid = p_pcentrocostoid) 
                AND (departamentoid = p_pdepartamentoid) 
                AND (lugarpagoid = p_plugarpagoid) 
                AND (empresaid = p_pempresaid)
        ) ResultadoPaginado
        WHERE rownum BETWEEN (p_pagina - 1) * p_decuantos + 1 
        AND p_pagina * p_decuantos;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_listado_quintonivel_total(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id centro de costo
    p_pdivisionid VARCHAR(14),       -- id division
    p_pquintonivel VARCHAR(50),      -- texto de busqueda
    p_pagina INTEGER,                -- numero de pagina
    p_decuantos DECIMAL              -- total pagina
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_nombrelike VARCHAR(50);
    v_error INT;
    v_mensaje VARCHAR(100);
    v_totalreg DECIMAL(9,2);
    v_vdecimal DECIMAL(9,2);
    v_total INT;
    var_cursor alias for p_refcursor;
BEGIN
    -- Construir el patrón de búsqueda (fiel al original)
    v_nombrelike := '%' || UPPER(RTRIM(p_pquintonivel)) || '%';
    -- Calcular total de registros (fiel al original)
    SELECT (COUNT(*) / p_decuantos) INTO v_totalreg
    FROM (
        SELECT *
        FROM (
            SELECT 
                quintonivel.quintonivelid,
                UPPER(quintonivel.nombrequintonivel) AS nombrequintonivel,
                CASE 
                    WHEN EXISTS (
                        SELECT 1 FROM accesoxusuarioquintonivel 
                        WHERE accesoxusuarioquintonivel.usuarioid = p_pusuarioid 
                        AND accesoxusuarioquintonivel.empresaid = p_pempresaid
                        AND accesoxusuarioquintonivel.lugarpagoid = p_plugarpagoid
                        AND accesoxusuarioquintonivel.departamentoid = p_pdepartamentoid
                        AND accesoxusuarioquintonivel.centrocostoid = p_pcentrocostoid
                        AND accesoxusuarioquintonivel.divisionid = p_pdivisionid
                        AND accesoxusuarioquintonivel.quintonivelid = quintonivel.quintonivelid
                    )
                    THEN 'checked'
                    ELSE '' 
                END AS checkconsulta,
                ROW_NUMBER() OVER (ORDER BY quintonivel.quintonivelid) AS rownum
            FROM quintonivel
            WHERE 
                ((UPPER(RTRIM(quintonivel.nombrequintonivel)) LIKE v_nombrelike) 
                OR (UPPER(RTRIM(quintonivel.quintonivelid)) LIKE v_nombrelike)
                OR (p_pquintonivel = ''))
                AND (divisionid = p_pdivisionid) 
                AND (centrocostoid = p_pcentrocostoid) 
                AND (departamentoid = p_pdepartamentoid) 
                AND (lugarpagoid = p_plugarpagoid) 
                AND (empresaid = p_pempresaid)
        ) ResultadoPaginado
    ) AS comosifuerauntabla;
    -- Calcular decimal y total (fiel al original)
    v_vdecimal := v_totalreg - CAST(v_totalreg AS INTEGER);
    IF v_vdecimal > 0 THEN
        v_total := v_totalreg + 1;
    ELSE
        v_total := v_totalreg;
    END IF;
    -- Retornar resultado
    OPEN var_cursor FOR
        SELECT v_total AS total;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR 
        SELECT SQLERRM AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

-- =============================================
-- Autor: Emanuel Cuello (Migrado a PostgreSQL)
-- Creado el: 29-04-2019
-- Migrado el: 25-09-2025
-- Descripcion: Listar todos los centros de costo por RUT de empresa
-- Ejemplo: SELECT sp_centroscosto_listadoPorRutEmpresa('pcursor', '12345678-9');
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_centroscosto_listadoPorRutEmpresa(
    p_refcursor refcursor,
    p_rut_empresa text
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    var_sql TEXT;
BEGIN
    -- Construir consulta base
    var_sql := '
        SELECT 
            cc.centrocostoid,
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(cc.nombrecentrocosto, ''á'', ''a''), ''é'', ''e''), ''í'', ''i''), ''ó'', ''o''), ''ú'', ''u'') AS nombrecentrocosto
        FROM 
            centroscosto cc
        WHERE
            cc.empresaid = ''' || p_rut_empresa || '''
        GROUP BY 
            cc.centrocostoid, cc.nombrecentrocosto
        ORDER BY 
            cc.nombrecentrocosto ASC';
    
    -- Abrir cursor con la consulta
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_centroscosto_listadoPorRutEmpresa: %', SQLERRM;
END;
$BODY$;


-- =============================================
-- Autor: Emanuel Cuello (Migrado a PostgreSQL)
-- Creado el: 29-04-2019
-- Migrado el: 25-09-2025
-- Descripcion: Listar todas las divisiones por estructura jerárquica completa
-- Ejemplo: SELECT sp_division_listadoPorEstructura('pcursor', '12345678-9', 'LP001', 'DP001', 'CC001');
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_division_listadoPorEstructura(
    p_refcursor refcursor,
    p_rut_empresa text,
    p_lugar_pago_id text,
    p_departamento_id text,
    p_centro_costo_id text
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    var_sql TEXT;
BEGIN
    -- Construir consulta base
    var_sql := '
        SELECT 
            div.divisionid,
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(div.nombredivision, ''á'', ''a''), ''é'', ''e''), ''í'', ''i''), ''ó'', ''o''), ''ú'', ''u'') AS nombredivision
        FROM 
            division div
        WHERE
            div.centrocostoid = ''' || p_centro_costo_id || ''' 
            AND div.departamentoid = ''' || p_departamento_id || ''' 
            AND div.lugarpagoid = ''' || p_lugar_pago_id || ''' 
            AND div.empresaid = ''' || p_rut_empresa || '''
        GROUP BY 
            div.divisionid, div.nombredivision
        ORDER BY 
            div.nombredivision ASC';
    
    -- Abrir cursor con la consulta
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_division_listadoPorEstructura: %', SQLERRM;
END;
$BODY$;


-- =============================================
-- Autor: Emanuel Cuello (Migrado a PostgreSQL)
-- Creado el: 29-04-2019
-- Migrado el: 25-09-2025
-- Descripcion: Listar todas las divisiones por RUT de empresa
-- Ejemplo: SELECT sp_division_listadoPorRutEmpresa('pcursor', '12345678-9');
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_division_listadoPorRutEmpresa(
    p_refcursor refcursor,
    p_rut_empresa text
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    var_sql TEXT;
BEGIN
    -- Construir consulta base
    var_sql := '
        SELECT 
            div.divisionid,
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(div.nombredivision, ''á'', ''a''), ''é'', ''e''), ''í'', ''i''), ''ó'', ''o''), ''ú'', ''u'') AS nombredivision
        FROM 
            division div
        WHERE
            div.empresaid = ''' || p_rut_empresa || '''
        GROUP BY 
            div.divisionid, div.nombredivision
        ORDER BY 
            div.nombredivision ASC';
    
    -- Abrir cursor con la consulta
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_division_listadoPorRutEmpresa: %', SQLERRM;
END;
$BODY$;


CREATE OR REPLACE FUNCTION public.sp_division_obtenerPorEmpresa(
p_refcursor refcursor,
p_empresaid character varying,
p_lugarpagoid character varying,
p_departamentoid character varying,
p_centrocostoid character varying,
    p_divisionid character varying
    )
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
    SELECT
       divisionid,
    nombredivision As "Descripcion"
      FROM division d
      WHERE d.divisionid = p_divisionid
        AND d.centrocostoid = p_centrocostoid
        AND d.empresaid = p_empresaid
        AND d.lugarpagoid = p_lugarpagoid
        AND d.departamentoid = p_departamentoid;
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_excelempl_graba_dinamico(text, character varying, character varying, character varying, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_excelempl_graba_dinamico(text, character varying, character varying, character varying, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_excelempl_graba_dinamico(
	p_cursorname text,
	p_personaid character varying,
	p_nombre character varying,
	p_empresaid character varying,
	p_rolid integer,
	p_estado character varying,
	p_correo character varying,
	p_correoinstitucional character varying,
	p_usuarioid character varying,
	p_lugarpagoid character varying DEFAULT NULL,
	p_departamentoid character varying DEFAULT NULL,
	p_centrocostoid character varying DEFAULT NULL,
	p_divisionid character varying DEFAULT NULL,
	p_quintonivelid character varying DEFAULT NULL)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_ref             refcursor := p_cursorname;  -- apuntamos al nombre de cursor
    v_tipotransaccion text     := '';
BEGIN
    -- 1) Personas
    IF NOT EXISTS (SELECT 1 FROM personas WHERE personaid = p_personaid) THEN
        INSERT INTO personas(personaid,nombre,correo,fechanacimiento,eliminado,correoinstitucional)
        VALUES (p_personaid,p_nombre,p_correo,NULL,false,p_correoinstitucional);
    ELSE
        UPDATE personas
           SET nombre              = p_nombre,
               correo              = p_correo,
               correoinstitucional = p_correoinstitucional,
               eliminado           = false
         WHERE personaid = p_personaid;
    END IF;

    -- 2) Empleados - Insertar o actualizar con campos dinámicos
    IF NOT EXISTS (SELECT 1 FROM empleados WHERE empleadoid = p_personaid) THEN
        INSERT INTO empleados(
            empleadoid,
            RutEmpresa,
            rolid,
            idestadoempleado,
            lugarpagoid,
            departamentoid,
            centrocostoid,
            divisionid,
            quintonivelid
        )
        VALUES (
            p_personaid,
            p_empresaid,
            p_rolid,
            p_estado,
            p_lugarpagoid,
            p_departamentoid,
            p_centrocostoid,
            p_divisionid,
            p_quintonivelid
        );
        v_tipotransaccion := 'Registro nuevo';
    ELSE
        UPDATE empleados
           SET RutEmpresa         = p_empresaid,
               rolid              = p_rolid,
               idestadoempleado   = p_estado,
               lugarpagoid        = p_lugarpagoid,
               departamentoid     = p_departamentoid,
               centrocostoid      = p_centrocostoid,
               divisionid         = p_divisionid,
               quintonivelid      = p_quintonivelid
         WHERE empleadoid = p_personaid;
        v_tipotransaccion := 'Registro modificado';
    END IF;

    -- 3) detalle en Excelempl
    IF NOT EXISTS (SELECT 1 FROM excelempl WHERE rutempleado = p_personaid) THEN
        INSERT INTO excelempl(rutempleado,rutusuario)
        VALUES (p_personaid,p_usuarioid);
    ELSE
        UPDATE excelempl
           SET rutusuario = p_usuarioid
         WHERE rutempleado = p_personaid;
    END IF;

    -- 4) Abrimos el cursor con el resultado
    OPEN v_ref FOR
      SELECT 0               AS error,
             ''              AS mensaje,
             v_tipotransaccion AS tipotransaccion;
    RETURN v_ref;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_acctodo_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_acctodo_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_acctodo_centrocosto(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying,
	p_centrocostoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER := 0;
    v_mensaje VARCHAR(100) := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    -- Verificar si existe la relación usuario-empresa, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioempresas
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid
    ) THEN
        INSERT INTO g_accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_usuarioid, p_empresaid);
    END IF;
    
    -- Verificar si existe la relación usuario-lugar de pago, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariolugarespago
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
    ) THEN
        INSERT INTO g_accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid);
    END IF;
    
    -- Verificar si existe la relación usuario-departamento, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodepartamento
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
    ) THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid);
    END IF;
    
    -- Verificar si existe la relación usuario-centro de costo, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioccosto
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
        AND centrocostoid = p_centrocostoid
    ) THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid, p_centrocostoid);
    END IF;
    
    -- Nivel 4: Insertar permisos para divisiones
    IF v_niveles >= 4 THEN
        INSERT INTO g_accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        LEFT JOIN g_accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                   AND ACC.empresaid = p_empresaid
                                                   AND ACC.lugarpagoid = LP.lugarpagoid
                                                   AND ACC.departamentoid = DP.departamentoid
                                                   AND ACC.centrocostoid = CC.centrocostoid
                                                   AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid;
    END IF;
    
    -- Nivel 5: Insertar permisos para quinto nivel
    IF v_niveles >= 5 THEN
        INSERT INTO g_accesoxusuarioquintonivel (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid, QN.quintonivelid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        INNER JOIN quinto_nivel QN ON CC.lugarpagoid = QN.lugarpagoid 
                                  AND CC.empresaid = QN.empresaid 
                                  AND CC.departamentoid = QN.departamentoid 
                                  AND CC.centrocostoid = QN.centrocostoid
                                  AND DIV.divisionid = QN.divisionid
        LEFT JOIN g_accesoxusuarioquintonivel AS ACC ON ACC.usuarioid = p_usuarioid
                                                       AND ACC.empresaid = p_empresaid
                                                       AND ACC.lugarpagoid = LP.lugarpagoid
                                                       AND ACC.departamentoid = DP.departamentoid
                                                       AND ACC.centrocostoid = CC.centrocostoid
                                                       AND ACC.divisionid = DIV.divisionid
                                                       AND ACC.quintonivelid = QN.quintonivelid
        WHERE ACC.quintonivelid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid;
    END IF;
    
    -- Retornar resultado
    v_error := 0;
    v_mensaje := '';
    
    -- Abrir cursor con el resultado
    OPEN p_refcursor FOR 
    SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error := 1;
        v_mensaje := 'Error: ' || SQLERRM;
        
        -- Abrir cursor con el error
        OPEN p_refcursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
        
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_acctodo_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_acctodo_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_acctodo_division(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying,
	p_centrocostoid character varying,
	p_divisionid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER := 0;
    v_mensaje VARCHAR(100) := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    -- Verificar si existe la relación usuario-empresa, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioempresas
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid
    ) THEN
        INSERT INTO g_accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_usuarioid, p_empresaid);
    END IF;
    
    -- Verificar si existe la relación usuario-lugar de pago, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariolugarespago
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
    ) THEN
        INSERT INTO g_accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid);
    END IF;
    
    -- Verificar si existe la relación usuario-departamento, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodepartamento
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
    ) THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid);
    END IF;
    
    -- Verificar si existe la relación usuario-centro de costo, si no existe la creamos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioccosto
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid
        AND departamentoid = p_departamentoid
        AND centrocostoid = p_centrocostoid
    ) THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_usuarioid, p_empresaid, p_lugarpagoid, p_departamentoid, p_centrocostoid);
    END IF;
    
    -- Insertar permisos para divisiones
    INSERT INTO g_accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
    SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid
    FROM lugarespago AS LP
    INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
    INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                AND CC.empresaid = DP.empresaid 
                                AND CC.departamentoid = DP.departamentoid
    INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                            AND DIV.empresaid = CC.empresaid 
                            AND DIV.departamentoid = CC.departamentoid 
                            AND DIV.centrocostoid = CC.centrocostoid
    LEFT JOIN g_accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                               AND ACC.empresaid = p_empresaid
                                               AND ACC.lugarpagoid = LP.lugarpagoid
                                               AND ACC.departamentoid = DP.departamentoid
                                               AND ACC.centrocostoid = CC.centrocostoid
                                               AND ACC.divisionid = DIV.divisionid
    WHERE ACC.divisionid IS NULL
    AND LP.empresaid = p_empresaid
    AND LP.lugarpagoid = p_lugarpagoid
    AND DP.departamentoid = p_departamentoid
    AND CC.centrocostoid = p_centrocostoid;
    
    -- Nivel 5: Insertar permisos para quinto nivel
    IF v_niveles >= 5 THEN
        INSERT INTO g_accesoxusuarioquintonivel (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid, DIV.divisionid, QN.quintonivelid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        INNER JOIN division DIV ON DIV.lugarpagoid = CC.lugarpagoid 
                                AND DIV.empresaid = CC.empresaid 
                                AND DIV.departamentoid = CC.departamentoid 
                                AND DIV.centrocostoid = CC.centrocostoid
        INNER JOIN quinto_nivel QN ON CC.lugarpagoid = QN.lugarpagoid 
                                  AND CC.empresaid = QN.empresaid 
                                  AND CC.departamentoid = QN.departamentoid 
                                  AND CC.centrocostoid = QN.centrocostoid
                                  AND DIV.divisionid = QN.divisionid
        LEFT JOIN g_accesoxusuarioquintonivel AS ACC ON ACC.usuarioid = p_usuarioid
                                                       AND ACC.empresaid = p_empresaid
                                                       AND ACC.lugarpagoid = LP.lugarpagoid
                                                       AND ACC.departamentoid = DP.departamentoid
                                                       AND ACC.centrocostoid = CC.centrocostoid
                                                       AND ACC.divisionid = DIV.divisionid
                                                       AND ACC.quintonivelid = QN.quintonivelid
        WHERE ACC.quintonivelid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid
        AND CC.centrocostoid = p_centrocostoid;
    END IF;
    
    -- Retornar resultado
    v_error := 0;
    v_mensaje := '';
    
    -- Abrir cursor con el resultado
    OPEN p_refcursor FOR 
    SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error := 1;
        v_mensaje := 'Error: ' || SQLERRM;
        
        -- Abrir cursor con el error
        OPEN p_refcursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
        
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_elimina_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_elimina_centrocosto(refcursor, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_elimina_centrocosto(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe el registro en centro de costo
    IF EXISTS (
        SELECT usuarioid FROM g_accesoxusuarioccosto 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuariodivision 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
            ) THEN
                DELETE FROM g_accesoxusuariodivision 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid;
            END IF;
        END IF;

        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
            ) THEN
                DELETE FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid;
            END IF;
        END IF;

        -- Eliminar el registro principal de centro de costo
        DELETE FROM g_accesoxusuarioccosto 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid;
    END IF;
    
    -- Retornar resultado exitoso
    v_error := 0;
    v_mensaje := '';
    
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN var_cursor;

EXCEPTION WHEN OTHERS THEN
    v_error := 1;
    v_mensaje := SQLERRM;
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_elimina_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_elimina_division(refcursor, character varying, character varying, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_elimina_division(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_pempresaid character varying,
	p_plugarpagoid character varying,
	p_pdepartamentoid character varying,
	p_pcentrocostoid character varying,
	p_pdivisionid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe el registro en división
    IF EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodivision
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid
    ) THEN
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
                AND divisionid = p_pdivisionid
            ) THEN
                DELETE FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_pusuarioid 
                AND empresaid = p_pempresaid 
                AND lugarpagoid = p_plugarpagoid
                AND departamentoid = p_pdepartamentoid
                AND centrocostoid = p_pcentrocostoid
                AND divisionid = p_pdivisionid;
            END IF;
        END IF;

        -- Eliminar el registro principal de división
        DELETE FROM g_accesoxusuariodivision 
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisionid;
    END IF;
    
    -- Retornar resultado exitoso
    v_error := 0;
    v_mensaje := '';
    
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    
    RETURN var_cursor;

EXCEPTION WHEN OTHERS THEN
    v_error := 1;
    v_mensaje := SQLERRM;
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
END;
$BODY$;


CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_graba_centrocosto(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14)     -- id del centro de costo
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    -- Verificar si existe el usuario en empresas
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioempresas
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid
    ) THEN
        INSERT INTO g_accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_pusuarioid, p_pempresaid);
    END IF;
    -- Verificar si existe el usuario en lugares de pago
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariolugarespago
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
    ) THEN
        INSERT INTO g_accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid);
    END IF;
    -- Verificar si existe el usuario en departamentos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodepartamento
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
    ) THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid);
    END IF;
    -- Verificar si existe el usuario en centros de costo
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioccosto
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid);
    END IF;
    -- Retornar resultado exitoso
    v_error := 0;
    v_mensaje := '';
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    v_error := 1;
    v_mensaje := SQLERRM;
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_graba_division(
    p_refcursor refcursor,
    p_pusuarioid VARCHAR(10),        -- id del usuario
    p_pempresaid VARCHAR(50),        -- id de la empresa
    p_plugarpagoid VARCHAR(14),      -- id lugar de pago
    p_pdepartamentoid VARCHAR(14),   -- id departamento
    p_pcentrocostoid VARCHAR(14),    -- id del centro de costo
    p_pdivisioid VARCHAR(14)          -- id del division
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error INTEGER;
    v_mensaje VARCHAR(100);
    var_cursor alias for p_refcursor;
BEGIN
    -- Verificar si existe el usuario en empresas
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioempresas
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid
    ) THEN
        INSERT INTO g_accesoxusuarioempresas (usuarioid, empresaid)
        VALUES (p_pusuarioid, p_pempresaid);
    END IF;
    -- Verificar si existe el usuario en lugares de pago
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariolugarespago
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
    ) THEN
        INSERT INTO g_accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid);
    END IF;
    -- Verificar si existe el usuario en departamentos
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodepartamento
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
    ) THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid);
    END IF;
    -- Verificar si existe el usuario en centros de costo
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuarioccosto
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
    ) THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid);
    END IF;
    -- Verificar si existe el usuario en divisiones
    IF NOT EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariodivision
        WHERE usuarioid = p_pusuarioid 
        AND empresaid = p_pempresaid 
        AND lugarpagoid = p_plugarpagoid
        AND departamentoid = p_pdepartamentoid
        AND centrocostoid = p_pcentrocostoid
        AND divisionid = p_pdivisioid
    ) THEN
        INSERT INTO g_accesoxusuariodivision (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        VALUES (p_pusuarioid, p_pempresaid, p_plugarpagoid, p_pdepartamentoid, p_pcentrocostoid, p_pdivisioid);
    END IF;
    -- Retornar resultado exitoso
    v_error := 0;
    v_mensaje := '';
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
EXCEPTION WHEN OTHERS THEN
    v_error := 1;
    v_mensaje := SQLERRM;
    OPEN var_cursor FOR 
        SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN var_cursor;
END;
$BODY$;

-- =============================================
-- Autor: Emanuel Cuello
-- Creado el: 25-09-2025
-- Descripcion: Listar todos el quintoniveles por estructura jerárquica completa
-- Ejemplo: SELECT sp_quintonivel_listadoPorEstructura('pcursor', '12345678-9', 'LP001', 'DP001', 'CC001', 'DIV001');
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_quintonivel_listadoPorEstructura(
    p_refcursor refcursor,
    p_rut_empresa text,
    p_lugar_pago_id text,
    p_departamento_id text,
    p_centro_costo_id text,
    p_division_id text
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    var_sql TEXT;
BEGIN
    -- Construir consulta base
    var_sql := '
        SELECT 
            qn.quintonivelid,
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(qn.nombrequintonivel, ''á'', ''a''), ''é'', ''e''), ''í'', ''i''), ''ó'', ''o''), ''ú'', ''u'') AS nombrequintonivel
        FROM 
            quinto_nivel qn
        WHERE
            qn.divisionid = ''' || p_division_id || ''' 
            AND qn.centrocostoid = ''' || p_centro_costo_id || ''' 
            AND qn.departamentoid = ''' || p_departamento_id || ''' 
            AND qn.lugarpagoid = ''' || p_lugar_pago_id || ''' 
            AND qn.empresaid = ''' || p_rut_empresa || '''
        GROUP BY 
            qn.quintonivelid, qn.nombrequintonivel
        ORDER BY 
            qn.nombrequintonivel ASC';
    
    -- Abrir cursor con la consulta
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_quintonivel_listadoPorEstructura: %', SQLERRM;
END;
$BODY$;


-- FUNCTION: public.sp_verificar_permiso_aprobar_documento(refcursor, integer, integer, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_verificar_permiso_aprobar_documento(refcursor, integer, integer, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_verificar_permiso_aprobar_documento(
    p_refcursor refcursor,
    p_iddocumento integer,
    p_ptipousuarioid integer,
    p_pusuarioid character varying,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_niveles  integer;
    v_existe   boolean := false;
BEGIN
    -- Obtener rol del usuario
    SELECT rolid INTO v_rolid FROM usuarios WHERE usuarioid = p_pusuarioid;
    
    IF v_rolid IS NULL THEN
        OPEN p_refcursor FOR 
            SELECT false AS tiene_permiso, 'Usuario no encontrado'::character varying AS mensaje;
        RETURN p_refcursor;
    END IF;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF p_debug = 1 THEN
        RAISE NOTICE '=== INICIO DEBUG SP_VERIFICAR_PERMISO_APROBAR_DOCUMENTO ===';
        RAISE NOTICE 'p_iddocumento: %', p_iddocumento;
        RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
        RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
        RAISE NOTICE 'v_rolid: %', v_rolid;
        RAISE NOTICE 'v_niveles: %', v_niveles;
    END IF;

    -- Construir consulta dinámica para verificar permisos
    var_sql :=
    'SELECT 
       COUNT(*) > 0 AS existe
     FROM contratos C
     INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
     INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc
       AND T.tipousuarioid = ' || quote_literal(p_ptipousuarioid) || '
     INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento';
    
    -- JOINs de niveles dinámicos (LEFT JOIN para obtener datos)
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN lugarespago LP ON LP.empresaid = C.RutEmpresa
         AND LP.lugarpagoid = CDV.LugarPagoid';
    END IF;

    IF v_niveles >= 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN departamentos DEP ON DEP.empresaid = C.RutEmpresa
         AND DEP.lugarpagoid = CDV.LugarPagoid
         AND DEP.departamentoid = CDV.departamentoid';
    END IF;

    IF v_niveles >= 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN centroscosto CCO ON CCO.empresaid = C.RutEmpresa
         AND CCO.lugarpagoid = CDV.LugarPagoid
         AND CCO.departamentoid = CDV.departamentoid
         AND CCO.centrocostoid = CDV.centrocosto';
    END IF;

    IF v_niveles >= 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 4: division';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN division DIV ON DIV.empresaid = C.RutEmpresa
         AND DIV.lugarpagoid = CDV.LugarPagoid
         AND DIV.departamentoid = CDV.departamentoid
         AND DIV.centrocostoid = CDV.centrocosto
         AND DIV.divisionid = CDV.divisionid';
    END IF;

    IF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        END IF;
        var_sql := var_sql || '
       LEFT JOIN quinto_nivel QN ON QN.empresaid = C.RutEmpresa
         AND QN.lugarpagoid = CDV.LugarPagoid
         AND QN.departamentoid = CDV.departamentoid
         AND QN.centrocostoid = CDV.centrocosto
         AND QN.divisionid = CDV.divisionid
         AND QN.quintonivelid = CDV.quintonivelid';
    END IF;
    
    -- INNER JOIN con permisos: esto es lo que realmente valida el acceso
    IF p_debug = 1 THEN
        RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS (INNER JOIN) ===';
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    END IF;
    
    IF v_niveles = 1 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.RutEmpresa
         AND ALP.lugarpagoid = CDV.LugarPagoid
         AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.RutEmpresa
         AND ADIV.lugarpagoid = CDV.LugarPagoid
         AND ADIV.departamentoid = CDV.departamentoid
         AND ADIV.centrocostoid = CDV.centrocosto
         AND ADIV.divisionid = CDV.divisionid
         AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        IF p_debug = 1 THEN
            RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.RutEmpresa
         AND AQN.lugarpagoid = CDV.LugarPagoid
         AND AQN.departamentoid = CDV.departamentoid
         AND AQN.centrocostoid = CDV.centrocosto
         AND AQN.divisionid = CDV.divisionid
         AND AQN.quintonivelid = CDV.quintonivelid
         AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;

    -- Validación de rol público si aplica
    IF v_rolid = 2 THEN
        var_sql := var_sql ||
        ' INNER JOIN empleados Emp ON CDV.Rut = Emp.empleadoid
          AND Emp.rolid = ' || v_rolid;
    END IF;

    -- WHERE: documento específico y no eliminado
    var_sql := var_sql ||
    ' WHERE C.idDocumento = ' || p_iddocumento || '
      AND C.Eliminado = false';

    IF p_debug = 1 THEN
        RAISE NOTICE '=== SQL FINAL GENERADO ===';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '=== FIN DEBUG ===';
    END IF;

    -- Ejecutar la consulta
    EXECUTE var_sql INTO v_existe;

    IF v_existe THEN
        OPEN p_refcursor FOR 
            SELECT 
                true AS tiene_permiso, 
                'El usuario tiene permiso para aprobar este documento'::character varying AS mensaje;
    ELSE
        OPEN p_refcursor FOR 
            SELECT 
                false AS tiene_permiso, 
                'El usuario no tiene permiso para aprobar este documento o el documento no existe'::character varying AS mensaje;
    END IF;
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR 
        SELECT 
            false AS tiene_permiso, 
            ('Error al verificar permisos: ' || SQLERRM)::character varying AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;



