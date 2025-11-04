-- FUNCTION: public.sp_accesoxusuario_acctodo_departamento(refcursor, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_acctodo_departamento(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_acctodo_departamento(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying)
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
    
    -- Nivel 3: Insertar permisos para centros de costo
    IF v_niveles >= 3 THEN
        INSERT INTO accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        LEFT JOIN accesoxusuarioccosto AS ACC ON ACC.usuarioid = p_usuarioid
                                               AND ACC.empresaid = p_empresaid
                                               AND ACC.lugarpagoid = LP.lugarpagoid
                                               AND ACC.departamentoid = DP.departamentoid
                                               AND ACC.centrocostoid = CC.centrocostoid
        WHERE ACC.centrocostoid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
        LEFT JOIN accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                 AND ACC.empresaid = p_empresaid
                                                 AND ACC.lugarpagoid = LP.lugarpagoid
                                                 AND ACC.departamentoid = DP.departamentoid
                                                 AND ACC.centrocostoid = CC.centrocostoid
                                                 AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
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
        AND DP.departamentoid = p_departamentoid;
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

-- FUNCTION: public.sp_accesoxusuario_acctodo_empresa(refcursor, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_acctodo_empresa(refcursor, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_acctodo_empresa(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying)
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
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- Nivel 1: Insertar permisos para lugares de pago
    IF v_niveles >= 1 THEN
        INSERT INTO accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid
        FROM lugarespago AS LP
        LEFT JOIN accesoxusuariolugarespago AS ACCLP ON ACCLP.usuarioid = p_usuarioid
                                                    AND ACCLP.empresaid = p_empresaid
                                                    AND ACCLP.lugarpagoid = LP.lugarpagoid
        WHERE ACCLP.lugarpagoid IS NULL 
        AND LP.empresaid = p_empresaid;
    END IF;
    
    -- Nivel 2: Insertar permisos para departamentos
    IF v_niveles >= 2 THEN
        INSERT INTO accesoxusuariodepartamentos (usuarioid, empresaid, lugarpagoid, departamentoid)
        SELECT p_usuarioid, p_empresaid, DP.lugarpagoid, DP.departamentoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        LEFT JOIN accesoxusuariodepartamentos AS ACDP ON ACDP.usuarioid = p_usuarioid
                                                       AND ACDP.empresaid = p_empresaid
                                                       AND ACDP.lugarpagoid = LP.lugarpagoid
                                                       AND ACDP.departamentoid = DP.departamentoid
        WHERE ACDP.departamentoid IS NULL
        AND LP.empresaid = p_empresaid;
    END IF;
    
    -- Nivel 3: Insertar permisos para centros de costo
    IF v_niveles >= 3 THEN
        INSERT INTO accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        LEFT JOIN accesoxusuarioccosto AS ACC ON ACC.usuarioid = p_usuarioid
                                               AND ACC.empresaid = p_empresaid
                                               AND ACC.lugarpagoid = LP.lugarpagoid
                                               AND ACC.departamentoid = DP.departamentoid
                                               AND ACC.centrocostoid = CC.centrocostoid
        WHERE ACC.centrocostoid IS NULL
        AND LP.empresaid = p_empresaid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
        LEFT JOIN accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                 AND ACC.empresaid = p_empresaid
                                                 AND ACC.lugarpagoid = LP.lugarpagoid
                                                 AND ACC.departamentoid = DP.departamentoid
                                                 AND ACC.centrocostoid = CC.centrocostoid
                                                 AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
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
        AND LP.empresaid = p_empresaid;
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

-- FUNCTION: public.sp_accesoxusuario_acctodo_lugarpago(refcursor, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_acctodo_lugarpago(refcursor, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_acctodo_lugarpago(
	p_refcursor refcursor,
	pusuarioid character varying,
	pempresaid character varying,
	plugarpagoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    error   INTEGER := 0;
    mensaje TEXT    := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Inserta en accesoxusuarioempresas si no existe la relación para la empresa y el usuario
    IF NOT EXISTS (
        SELECT 1 
        FROM accesoxusuarioempresas
        WHERE usuarioid = pusuarioid 
          AND empresaid = pempresaid
    ) THEN
        INSERT INTO accesoxusuarioempresas(usuarioid, empresaid)
        VALUES (pusuarioid, pempresaid);
    END IF;

    -- Inserta en accesoxusuariolugarespago si no existe la relación para el lugar de pago
    IF NOT EXISTS (
        SELECT 1 
        FROM accesoxusuariolugarespago
        WHERE usuarioid = pusuarioid 
          AND empresaid = pempresaid 
          AND lugarpagoid = plugarpagoid
    ) THEN
        INSERT INTO accesoxusuariolugarespago(usuarioid, empresaid, lugarpagoid)
        VALUES (pusuarioid, pempresaid, plugarpagoid);
    END IF;

    -- Nivel 2: Inserta en accesoxusuariodepartamentos para el lugar de pago indicado
    IF v_niveles >= 2 THEN
        INSERT INTO accesoxusuariodepartamentos(usuarioid, empresaid, lugarpagoid, departamentoid)
        SELECT pusuarioid, pempresaid, dp.lugarpagoid, dp.departamentoid
        FROM lugarespago lp
        JOIN departamentos dp 
             ON lp.lugarpagoid = dp.lugarpagoid 
            AND lp.empresaid = dp.empresaid
        LEFT JOIN accesoxusuariodepartamentos acdp
             ON acdp.usuarioid = pusuarioid 
            AND acdp.empresaid = pempresaid
            AND acdp.lugarpagoid = lp.lugarpagoid 
            AND acdp.departamentoid = dp.departamentoid
        WHERE acdp.departamentoid IS NULL
          AND lp.lugarpagoid = plugarpagoid
          AND lp.empresaid = pempresaid;
    END IF;

    -- Nivel 3: Inserta en accesoxusuarioccosto para el lugar de pago indicado
    IF v_niveles >= 3 THEN
        INSERT INTO accesoxusuarioccosto(usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT pusuarioid, pempresaid, lp.lugarpagoid, dp.departamentoid, cc.centrocostoid
        FROM lugarespago lp
        JOIN departamentos dp 
             ON lp.lugarpagoid = dp.lugarpagoid 
            AND lp.empresaid = dp.empresaid
        JOIN centroscosto cc 
             ON cc.lugarpagoid = dp.lugarpagoid 
            AND cc.empresaid = dp.empresaid 
            AND cc.departamentoid = dp.departamentoid
        LEFT JOIN accesoxusuarioccosto acc
             ON acc.usuarioid = pusuarioid 
            AND acc.empresaid = pempresaid
            AND acc.lugarpagoid = lp.lugarpagoid 
            AND acc.departamentoid = dp.departamentoid 
            AND acc.centrocostoid = cc.centrocostoid
        WHERE acc.centrocostoid IS NULL
          AND lp.empresaid = pempresaid
          AND lp.lugarpagoid = plugarpagoid;
    END IF;

    -- Nivel 4: Inserta en accesoxusuariodivision para el lugar de pago indicado
    IF v_niveles >= 4 THEN
        INSERT INTO accesoxusuariodivision(usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid)
        SELECT pusuarioid, pempresaid, lp.lugarpagoid, dp.departamentoid, cc.centrocostoid, div.divisionid
        FROM lugarespago lp
        JOIN departamentos dp 
             ON lp.lugarpagoid = dp.lugarpagoid 
            AND lp.empresaid = dp.empresaid
        JOIN centroscosto cc 
             ON cc.lugarpagoid = dp.lugarpagoid 
            AND cc.empresaid = dp.empresaid 
            AND cc.departamentoid = dp.departamentoid
        JOIN division div 
             ON cc.lugarpagoid = div.lugarpagoid 
            AND cc.empresaid = div.empresaid 
            AND cc.departamentoid = div.departamentoid 
            AND cc.centrocostoid = div.centrocostoid
        LEFT JOIN accesoxusuariodivision acc
             ON acc.usuarioid = pusuarioid
            AND acc.empresaid = pempresaid
            AND acc.lugarpagoid = lp.lugarpagoid
            AND acc.departamentoid = dp.departamentoid
            AND acc.centrocostoid = cc.centrocostoid
            AND acc.divisionid = div.divisionid
        WHERE acc.divisionid IS NULL
          AND lp.empresaid = pempresaid
          AND lp.lugarpagoid = plugarpagoid;
    END IF;

    -- Nivel 5: Inserta en accesoxusuarioquintonivel para el lugar de pago indicado
    IF v_niveles >= 5 THEN
        INSERT INTO accesoxusuarioquintonivel(usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid)
        SELECT pusuarioid, pempresaid, lp.lugarpagoid, dp.departamentoid, cc.centrocostoid, div.divisionid, qn.quintonivelid
        FROM lugarespago lp
        JOIN departamentos dp 
             ON lp.lugarpagoid = dp.lugarpagoid 
            AND lp.empresaid = dp.empresaid
        JOIN centroscosto cc 
             ON cc.lugarpagoid = dp.lugarpagoid 
            AND cc.empresaid = dp.empresaid 
            AND cc.departamentoid = dp.departamentoid
        JOIN division div 
             ON cc.lugarpagoid = div.lugarpagoid 
            AND cc.empresaid = div.empresaid 
            AND cc.departamentoid = div.departamentoid 
            AND cc.centrocostoid = div.centrocostoid
        JOIN quinto_nivel qn 
             ON cc.lugarpagoid = qn.lugarpagoid 
            AND cc.empresaid = qn.empresaid 
            AND cc.departamentoid = qn.departamentoid 
            AND cc.centrocostoid = qn.centrocostoid
            AND div.divisionid = qn.divisionid
        LEFT JOIN accesoxusuarioquintonivel acc
             ON acc.usuarioid = pusuarioid
            AND acc.empresaid = pempresaid
            AND acc.lugarpagoid = lp.lugarpagoid
            AND acc.departamentoid = dp.departamentoid
            AND acc.centrocostoid = cc.centrocostoid
            AND acc.divisionid = div.divisionid
            AND acc.quintonivelid = qn.quintonivelid
        WHERE acc.quintonivelid IS NULL
          AND lp.empresaid = pempresaid
          AND lp.lugarpagoid = plugarpagoid;
    END IF;

    -- Establece error y mensaje (en este caso, 0 y cadena vacía)
    error := 0;
    mensaje := '';

    -- Devuelve el estado final
    OPEN p_refcursor FOR
        SELECT error AS "error", mensaje AS "mensaje";
    RETURN p_refcursor;
EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR
        SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_accesoxusuario_elimina_departamento(refcursor, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_elimina_departamento(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_departamento(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying)
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
    
    -- Verificar si existe el registro en departamentos
    IF EXISTS (
        SELECT usuarioid FROM accesoxusuariodepartamentos 
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid 
        AND departamentoid = p_departamentoid
    ) THEN
        -- Nivel 3: Centro de Costo (desde nivel 3 hacia abajo)
        IF v_niveles >= 3 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid 
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Eliminar el registro principal de departamentos
        DELETE FROM accesoxusuariodepartamentos 
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid 
        AND departamentoid = p_departamentoid;
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

-- FUNCTION: public.sp_accesoxusuario_elimina_empresa(refcursor, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_elimina_empresa(refcursor, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_empresa(
	p_refcursor refcursor,
	pusuarioid character varying,
	pempresaid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor  ALIAS FOR p_refcursor;
    var_error   INTEGER := 0;
    var_mensaje VARCHAR := '';
    v_niveles   INTEGER := 0;
BEGIN
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    IF EXISTS(SELECT 1 FROM accesoxusuarioempresas WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
        IF v_niveles >= 1 THEN
            -- Nivel 1: Lugares de Pago
            IF EXISTS(SELECT 1 FROM accesoxusuariolugarespago WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
                DELETE FROM accesoxusuariolugarespago
                WHERE usuarioid = pusuarioid AND empresaid = pempresaid;
            END IF;
        END IF;
        IF v_niveles >= 2 THEN
            -- Nivel 2: Departamentos
            IF EXISTS(SELECT 1 FROM accesoxusuariodepartamentos WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
                DELETE FROM accesoxusuariodepartamentos
                WHERE usuarioid = pusuarioid AND empresaid = pempresaid;
            END IF;
        END IF;
        IF v_niveles >= 3 THEN
            -- Nivel 3: Centro de Costo
            IF EXISTS(SELECT 1 FROM accesoxusuarioccosto WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
                DELETE FROM accesoxusuarioccosto
                WHERE usuarioid = pusuarioid AND empresaid = pempresaid;
            END IF;
        END IF;
        IF v_niveles >= 4 THEN
            -- Nivel 4: División
            IF EXISTS(SELECT 1 FROM accesoxusuariodivision WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
                DELETE FROM accesoxusuariodivision
                WHERE usuarioid = pusuarioid AND empresaid = pempresaid;
            END IF;
        END IF;
        IF v_niveles >= 5 THEN
            -- Nivel 5: Quinto Nivel
            IF EXISTS(SELECT 1 FROM accesoxusuarioquintonivel WHERE usuarioid = pusuarioid AND empresaid = pempresaid) THEN
                DELETE FROM accesoxusuarioquintonivel
                WHERE usuarioid = pusuarioid AND empresaid = pempresaid;
            END IF;
        END IF;
        DELETE FROM accesoxusuarioempresas
        WHERE usuarioid = pusuarioid AND empresaid = pempresaid;

        var_error := 0;
        var_mensaje := '';
    END IF;

    OPEN var_cursor FOR SELECT var_error AS "error", var_mensaje AS "mensaje";
    RETURN var_cursor;
END;
$BODY$;

-- FUNCTION: public.sp_accesoxusuario_elimina_lugarpago(refcursor, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_accesoxusuario_elimina_lugarpago(refcursor, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_accesoxusuario_elimina_lugarpago(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    v_niveles INTEGER := 0;
BEGIN
    -- Inicializar variables
    var_error := 0;
    var_mensaje := '';
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe el registro en lugares de pago
    IF EXISTS (
        SELECT usuarioid 
        FROM accesoxusuariolugarespago 
        WHERE usuarioid = p_usuarioid 
            AND empresaid = p_empresaid 
            AND lugarpagoid = p_lugarpagoid
    ) THEN
        -- Nivel 2: Departamentos (desde nivel 2 hacia abajo)
        IF v_niveles >= 2 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM accesoxusuariodepartamentos 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM accesoxusuariodepartamentos
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 3: Centro de Costo (desde nivel 3 hacia abajo)
        IF v_niveles >= 3 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM accesoxusuarioccosto
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM accesoxusuariodivision
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM accesoxusuarioquintonivel
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Eliminar el registro principal de lugares de pago
        DELETE FROM accesoxusuariolugarespago 
        WHERE usuarioid = p_usuarioid 
            AND empresaid = p_empresaid 
            AND lugarpagoid = p_lugarpagoid;
    END IF;
    
    -- Retornar resultado
    OPEN p_refcursor FOR
        SELECT var_error::INTEGER AS error, var_mensaje AS mensaje;
    
    RETURN p_refcursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_confimparchivodet_count(
    p_refcursor refcursor,
    p_idarchivo integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_total integer;
    var_niveles_activos integer;
BEGIN
    -- Contar registros base para el archivo indicado
    SELECT COUNT(*) INTO var_total
    FROM confimparchivodet
    WHERE idarchivo = p_idarchivo;

    -- Obtener cantidad de niveles activos del cliente
    SELECT COUNT(*) INTO var_niveles_activos
    FROM niveles_estructura
    WHERE activo = true;

    -- Ajustar total según cantidad de niveles activos (base: 5 niveles en tabla)
    var_total := var_total - (5 - var_niveles_activos);

    -- Retornar resultado en formato esperado por el front-end
    OPEN p_refcursor FOR
    SELECT
        var_total AS "total",
        ''::text  AS "mensaje";

    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_contratodatosvariables_agregar(refcursor, integer, text, text, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text)

-- DROP FUNCTION IF EXISTS public.sp_contratodatosvariables_agregar(refcursor, integer, text, text, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.sp_contratodatosvariables_agregar(
	p_refcursor refcursor,
	p_piddocumento integer,
	p_rut text,
	p_fechadocumento text,
	p_afp text,
	p_banco text,
	p_cargo text,
	p_colacion integer,
	p_fechaingreso text,
	p_fechainicio text,
	p_fechatermino text,
	p_horas text,
	p_jornada text,
	p_movilizacion integer,
	p_nombrecontactoemergencia text,
	p_tipocuenta text,
	p_nrocuenta text,
	p_salud text,
	p_sueldobase text,
	p_bonotelefono integer,
	p_telefonocontactoemergencia text,
	p_texto1 text,
	p_texto2 text,
	p_texto3 text,
	p_texto4 text,
	p_texto5 text,
	p_texto6 text,
	p_texto7 text,
	p_texto8 text,
	p_texto9 text,
	p_texto10 text,
	p_texto11 text,
	p_texto12 text,
	p_texto13 text,
	p_texto14 text,
	p_texto15 text,
	p_texto16 text,
	p_texto17 text,
	p_texto18 text,
	p_texto19 text,
	p_texto20 text,
	p_areafuncional text,
	p_lugarpagoid text DEFAULT NULL,
	p_departamentoid text DEFAULT NULL,
	p_centrocostoid text DEFAULT NULL,
	p_divisionid text DEFAULT NULL,
	p_quintonivelid text DEFAULT NULL)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_ref ALIAS FOR p_refcursor;
    v_error integer := 0;
    v_mensaje text := '';
    v_niveles integer;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF NOT EXISTS (
        SELECT 1 FROM contratodatosvariables WHERE iddocumento = p_piddocumento
    ) THEN
        -- Insertar con niveles dinámicos
        IF v_niveles = 1 THEN
            INSERT INTO contratodatosvariables (
                iddocumento, rut, lugarpagoid,
                fechadocumento, afp, banco, cargo, colacion,
                fechaingreso, fechainicio, fechatermino,
                horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase,
                bonotelefono, telefonocontactoemergencia,
                texto1, texto2, texto3, texto4, texto5,
                texto6, texto7, texto8, texto9, texto10,
                texto11, texto12, texto13, texto14, texto15,
                texto16, texto17, texto18, texto19, texto20,
                areafuncional
            )
            VALUES (
                p_piddocumento, p_rut, p_lugarpagoid,
                NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
                NULLIF(p_fechaingreso, '')::date,
                NULLIF(p_fechainicio, '')::date,
                NULLIF(p_fechatermino, '')::date,
                p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
                p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
                p_bonotelefono, p_telefonocontactoemergencia,
                p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
                p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
                p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
                p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
                p_areafuncional
            );
        ELSIF v_niveles = 2 THEN
            INSERT INTO contratodatosvariables (
                iddocumento, rut, lugarpagoid, departamentoid,
                fechadocumento, afp, banco, cargo, colacion,
                fechaingreso, fechainicio, fechatermino,
                horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase,
                bonotelefono, telefonocontactoemergencia,
                texto1, texto2, texto3, texto4, texto5,
                texto6, texto7, texto8, texto9, texto10,
                texto11, texto12, texto13, texto14, texto15,
                texto16, texto17, texto18, texto19, texto20,
                areafuncional
            )
            VALUES (
                p_piddocumento, p_rut, p_lugarpagoid, p_departamentoid,
                NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
                NULLIF(p_fechaingreso, '')::date,
                NULLIF(p_fechainicio, '')::date,
                NULLIF(p_fechatermino, '')::date,
                p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
                p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
                p_bonotelefono, p_telefonocontactoemergencia,
                p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
                p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
                p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
                p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
                p_areafuncional
            );
        ELSIF v_niveles = 3 THEN
            INSERT INTO contratodatosvariables (
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto,
                fechadocumento, afp, banco, cargo, colacion,
                fechaingreso, fechainicio, fechatermino,
                horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase,
                bonotelefono, telefonocontactoemergencia,
                texto1, texto2, texto3, texto4, texto5,
                texto6, texto7, texto8, texto9, texto10,
                texto11, texto12, texto13, texto14, texto15,
                texto16, texto17, texto18, texto19, texto20,
                areafuncional
            )
            VALUES (
                p_piddocumento, p_rut, p_lugarpagoid, p_departamentoid, p_centrocostoid,
                NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
                NULLIF(p_fechaingreso, '')::date,
                NULLIF(p_fechainicio, '')::date,
                NULLIF(p_fechatermino, '')::date,
                p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
                p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
                p_bonotelefono, p_telefonocontactoemergencia,
                p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
                p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
                p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
                p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
                p_areafuncional
            );
        ELSIF v_niveles = 4 THEN
            INSERT INTO contratodatosvariables (
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto, divisionid,
                fechadocumento, afp, banco, cargo, colacion,
                fechaingreso, fechainicio, fechatermino,
                horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase,
                bonotelefono, telefonocontactoemergencia,
                texto1, texto2, texto3, texto4, texto5,
                texto6, texto7, texto8, texto9, texto10,
                texto11, texto12, texto13, texto14, texto15,
                texto16, texto17, texto18, texto19, texto20,
                areafuncional
            )
            VALUES (
                p_piddocumento, p_rut, p_lugarpagoid, p_departamentoid, p_centrocostoid, p_divisionid,
                NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
                NULLIF(p_fechaingreso, '')::date,
                NULLIF(p_fechainicio, '')::date,
                NULLIF(p_fechatermino, '')::date,
                p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
                p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
                p_bonotelefono, p_telefonocontactoemergencia,
                p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
                p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
                p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
                p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
                p_areafuncional
            );
        ELSIF v_niveles = 5 THEN
            INSERT INTO contratodatosvariables (
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto, divisionid, quintonivelid,
                fechadocumento, afp, banco, cargo, colacion,
                fechaingreso, fechainicio, fechatermino,
                horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase,
                bonotelefono, telefonocontactoemergencia,
                texto1, texto2, texto3, texto4, texto5,
                texto6, texto7, texto8, texto9, texto10,
                texto11, texto12, texto13, texto14, texto15,
                texto16, texto17, texto18, texto19, texto20,
                areafuncional
            )
            VALUES (
                p_piddocumento, p_rut, p_lugarpagoid, p_departamentoid, p_centrocostoid, p_divisionid, p_quintonivelid,
                NULLIF(p_fechadocumento, '')::date, p_afp, p_banco, p_cargo, p_colacion,
                NULLIF(p_fechaingreso, '')::date,
                NULLIF(p_fechainicio, '')::date,
                NULLIF(p_fechatermino, '')::date,
                p_horas, p_jornada, p_movilizacion, p_nombrecontactoemergencia,
                p_tipocuenta, p_nrocuenta, p_salud, NULLIF(p_sueldobase, '')::integer,
                p_bonotelefono, p_telefonocontactoemergencia,
                p_texto1, p_texto2, p_texto3, p_texto4, p_texto5,
                p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
                p_texto11, p_texto12, p_texto13, p_texto14, p_texto15,
                p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
                p_areafuncional
            );
        END IF;
    ELSE
        -- Actualizar con niveles dinámicos
        IF v_niveles = 1 THEN
            UPDATE contratodatosvariables SET
                rut = p_rut,
                lugarpagoid = p_lugarpagoid,
                fechadocumento = NULLIF(p_fechadocumento, '')::date,
                afp = p_afp,
                banco = p_banco,
                cargo = p_cargo,
                colacion = p_colacion,
                fechaingreso = NULLIF(p_fechaingreso, '')::date,
                fechainicio = NULLIF(p_fechainicio, '')::date,
                fechatermino = NULLIF(p_fechatermino, '')::date,
                horas = p_horas,
                jornada = p_jornada,
                movilizacion = p_movilizacion,
                nombrecontactoemergencia = p_nombrecontactoemergencia,
                tipocuenta = p_tipocuenta,
                nrocuenta = p_nrocuenta,
                salud = p_salud,
                sueldobase = NULLIF(p_sueldobase, '')::integer,
                bonotelefono = p_bonotelefono,
                telefonocontactoemergencia = p_telefonocontactoemergencia,
                texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
                texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
                texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
                texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
                texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
                texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
                texto19 = p_texto19, texto20 = p_texto20,
                areafuncional = p_areafuncional
            WHERE iddocumento = p_piddocumento;
        ELSIF v_niveles = 2 THEN
            UPDATE contratodatosvariables SET
                rut = p_rut,
                lugarpagoid = p_lugarpagoid,
                departamentoid = p_departamentoid,
                fechadocumento = NULLIF(p_fechadocumento, '')::date,
                afp = p_afp,
                banco = p_banco,
                cargo = p_cargo,
                colacion = p_colacion,
                fechaingreso = NULLIF(p_fechaingreso, '')::date,
                fechainicio = NULLIF(p_fechainicio, '')::date,
                fechatermino = NULLIF(p_fechatermino, '')::date,
                horas = p_horas,
                jornada = p_jornada,
                movilizacion = p_movilizacion,
                nombrecontactoemergencia = p_nombrecontactoemergencia,
                tipocuenta = p_tipocuenta,
                nrocuenta = p_nrocuenta,
                salud = p_salud,
                sueldobase = NULLIF(p_sueldobase, '')::integer,
                bonotelefono = p_bonotelefono,
                telefonocontactoemergencia = p_telefonocontactoemergencia,
                texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
                texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
                texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
                texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
                texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
                texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
                texto19 = p_texto19, texto20 = p_texto20,
                areafuncional = p_areafuncional
            WHERE iddocumento = p_piddocumento;
        ELSIF v_niveles = 3 THEN
            UPDATE contratodatosvariables SET
                rut = p_rut,
                lugarpagoid = p_lugarpagoid,
                departamentoid = p_departamentoid,
                centrocosto = p_centrocostoid,
                fechadocumento = NULLIF(p_fechadocumento, '')::date,
                afp = p_afp,
                banco = p_banco,
                cargo = p_cargo,
                colacion = p_colacion,
                fechaingreso = NULLIF(p_fechaingreso, '')::date,
                fechainicio = NULLIF(p_fechainicio, '')::date,
                fechatermino = NULLIF(p_fechatermino, '')::date,
                horas = p_horas,
                jornada = p_jornada,
                movilizacion = p_movilizacion,
                nombrecontactoemergencia = p_nombrecontactoemergencia,
                tipocuenta = p_tipocuenta,
                nrocuenta = p_nrocuenta,
                salud = p_salud,
                sueldobase = NULLIF(p_sueldobase, '')::integer,
                bonotelefono = p_bonotelefono,
                telefonocontactoemergencia = p_telefonocontactoemergencia,
                texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
                texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
                texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
                texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
                texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
                texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
                texto19 = p_texto19, texto20 = p_texto20,
                areafuncional = p_areafuncional
            WHERE iddocumento = p_piddocumento;
        ELSIF v_niveles = 4 THEN
            UPDATE contratodatosvariables SET
                rut = p_rut,
                lugarpagoid = p_lugarpagoid,
                departamentoid = p_departamentoid,
                centrocosto = p_centrocostoid,
                divisionid = p_divisionid,
                fechadocumento = NULLIF(p_fechadocumento, '')::date,
                afp = p_afp,
                banco = p_banco,
                cargo = p_cargo,
                colacion = p_colacion,
                fechaingreso = NULLIF(p_fechaingreso, '')::date,
                fechainicio = NULLIF(p_fechainicio, '')::date,
                fechatermino = NULLIF(p_fechatermino, '')::date,
                horas = p_horas,
                jornada = p_jornada,
                movilizacion = p_movilizacion,
                nombrecontactoemergencia = p_nombrecontactoemergencia,
                tipocuenta = p_tipocuenta,
                nrocuenta = p_nrocuenta,
                salud = p_salud,
                sueldobase = NULLIF(p_sueldobase, '')::integer,
                bonotelefono = p_bonotelefono,
                telefonocontactoemergencia = p_telefonocontactoemergencia,
                texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
                texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
                texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
                texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
                texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
                texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
                texto19 = p_texto19, texto20 = p_texto20,
                areafuncional = p_areafuncional
            WHERE iddocumento = p_piddocumento;
        ELSIF v_niveles = 5 THEN
            UPDATE contratodatosvariables SET
                rut = p_rut,
                lugarpagoid = p_lugarpagoid,
                departamentoid = p_departamentoid,
                centrocosto = p_centrocostoid,
                divisionid = p_divisionid,
                quintonivelid = p_quintonivelid,
                fechadocumento = NULLIF(p_fechadocumento, '')::date,
                afp = p_afp,
                banco = p_banco,
                cargo = p_cargo,
                colacion = p_colacion,
                fechaingreso = NULLIF(p_fechaingreso, '')::date,
                fechainicio = NULLIF(p_fechainicio, '')::date,
                fechatermino = NULLIF(p_fechatermino, '')::date,
                horas = p_horas,
                jornada = p_jornada,
                movilizacion = p_movilizacion,
                nombrecontactoemergencia = p_nombrecontactoemergencia,
                tipocuenta = p_tipocuenta,
                nrocuenta = p_nrocuenta,
                salud = p_salud,
                sueldobase = NULLIF(p_sueldobase, '')::integer,
                bonotelefono = p_bonotelefono,
                telefonocontactoemergencia = p_telefonocontactoemergencia,
                texto1 = p_texto1, texto2 = p_texto2, texto3 = p_texto3,
                texto4 = p_texto4, texto5 = p_texto5, texto6 = p_texto6,
                texto7 = p_texto7, texto8 = p_texto8, texto9 = p_texto9,
                texto10 = p_texto10, texto11 = p_texto11, texto12 = p_texto12,
                texto13 = p_texto13, texto14 = p_texto14, texto15 = p_texto15,
                texto16 = p_texto16, texto17 = p_texto17, texto18 = p_texto18,
                texto19 = p_texto19, texto20 = p_texto20,
                areafuncional = p_areafuncional
            WHERE iddocumento = p_piddocumento;
        END IF;
    END IF;

    OPEN v_ref FOR
    SELECT v_error AS "error", v_mensaje AS "mensaje";

    RETURN v_ref;

EXCEPTION WHEN OTHERS THEN
    OPEN v_ref FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN v_ref;
END;
$BODY$;
CREATE OR REPLACE FUNCTION public.sp_contratodatosvariables_obtener(
	p_refcursor refcursor,
	p_iddocumento integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql text;
    v_niveles integer;
    v_nombre_nivel1 varchar(50);
    v_nombre_nivel2 varchar(50);
    v_nombre_nivel3 varchar(50);
    v_nombre_nivel4 varchar(50);
    v_nombre_nivel5 varchar(50);
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener nombres de niveles desde niveles_estructura
    IF v_niveles >= 1 THEN
        SELECT nombre INTO v_nombre_nivel1 FROM niveles_estructura WHERE nivel = 1 AND activo = true;
        RAISE NOTICE 'Nombre nivel 1: %', v_nombre_nivel1;
    END IF;
    
    IF v_niveles >= 2 THEN
        SELECT nombre INTO v_nombre_nivel2 FROM niveles_estructura WHERE nivel = 2 AND activo = true;
        RAISE NOTICE 'Nombre nivel 2: %', v_nombre_nivel2;
    END IF;
    
    IF v_niveles >= 3 THEN
        SELECT nombre INTO v_nombre_nivel3 FROM niveles_estructura WHERE nivel = 3 AND activo = true;
        RAISE NOTICE 'Nombre nivel 3: %', v_nombre_nivel3;
    END IF;
    
    IF v_niveles >= 4 THEN
        SELECT nombre INTO v_nombre_nivel4 FROM niveles_estructura WHERE nivel = 4 AND activo = true;
        RAISE NOTICE 'Nombre nivel 4: %', v_nombre_nivel4;
    END IF;
    
    IF v_niveles = 5 THEN
        SELECT nombre INTO v_nombre_nivel5 FROM niveles_estructura WHERE nivel = 5 AND activo = true;
        RAISE NOTICE 'Nombre nivel 5: %', v_nombre_nivel5;
    END IF;

    -- Campos base (siempre presentes)
    var_sql := '
    SELECT 
        CV.iddocumento AS "idDocumento",
        CV.rut AS "Rut",
        CV.afp AS "Afp",
        CV.banco AS "Banco",
        CV.cargo AS "idCargoEmpleado",
        CV.colacion AS "Colacion",
        TO_CHAR(CV.fechadocumento, ''DD-MM-YYYY'') AS "FechaDocumento",
        TO_CHAR(CV.fechaingreso, ''DD-MM-YYYY'') AS "FechaIngreso",
        TO_CHAR(CV.fechainicio, ''DD-MM-YYYY'') AS "FechaInicio",
        TO_CHAR(CV.fechatermino, ''DD-MM-YYYY'') AS "FechaTermino",
        CV.horas AS "Horas",
        CV.jornada AS "idJornada",
        CV.jornada AS "Jornada",
        CV.movilizacion AS "Movilizacion",
        CV.nombrecontactoemergencia AS "NombreContactoEmergencia",
        CV.tipocuenta AS "TipoCuenta",
        CV.nrocuenta AS "NroCuenta",
        CV.salud AS "Salud",
        CV.sueldobase AS "SueldoBase",
        CV.telefono AS "Telefono",
        CV.telefonocontactoemergencia AS "TelefonoContactoEmergencia",
        CV.texto1 AS "Texto1",
        CV.texto2 AS "Texto2",
        CV.texto3 AS "Texto3",
        CV.texto4 AS "Texto4",
        CV.texto5 AS "Texto5",
        CV.texto6 AS "Texto6",
        CV.texto7 AS "Texto7",
        CV.texto8 AS "Texto8",
        CV.texto9 AS "Texto9",
        CV.texto10 AS "Texto10",
        CV.texto11 AS "Texto11",
        CV.texto12 AS "Texto12",
        CV.texto13 AS "Texto13",
        CV.texto14 AS "Texto14",
        CV.texto15 AS "Texto15",
        CV.texto16 AS "Texto16",
        CV.texto17 AS "Texto17",
        CV.texto18 AS "Texto18",
        CV.texto19 AS "Texto19",
        CV.texto20 AS "Texto20",
        CEm.descripcion AS "Descripcion",
        CEm.idcargoempleado AS "CodCargo",
        CEm.descripcion AS "DescripcionCargo",
        CEm.descripcion AS "TextoCargo",
        CASE WHEN COALESCE(CEm.titulo, '''') = '''' THEN CV.cargo ELSE CEm.titulo END AS "TituloCargo",
        CASE WHEN COALESCE(CEm.titulo, '''') = '''' THEN CV.cargo ELSE CEm.titulo END AS "Cargo",
        CV.bonotelefono AS "BonoTelefono",
        CV.areafuncional AS "AreaFuncional"';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
        CV.lugarpagoid AS "lugarpagoid",
        lp.nombrelugarpago AS "nombrelugarpago",
        lp.nombrelugarpago AS "' || v_nombre_nivel1 || '"';
        RAISE NOTICE 'Agregando campos nivel 1: lugarespago (%) ', v_nombre_nivel1;
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
        CV.departamentoid AS "departamentoid",
        dp.nombredepartamento AS "nombredepartamento",
        dp.nombredepartamento AS "' || v_nombre_nivel2 || '"';
        RAISE NOTICE 'Agregando campos nivel 2: departamentos (%) ', v_nombre_nivel2;
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
        CV.centrocosto AS "centrocostoid",
        cco.nombrecentrocosto AS "nombrecentrocosto",
        cco.nombrecentrocosto AS "' || v_nombre_nivel3 || '"';
        RAISE NOTICE 'Agregando campos nivel 3: centroscosto (%) ', v_nombre_nivel3;
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
        CV.divisionid AS "divisionid",
        div.nombredivision AS "nombredivision",
        div.nombredivision AS "' || v_nombre_nivel4 || '"';
        RAISE NOTICE 'Agregando campos nivel 4: division (%) ', v_nombre_nivel4;
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
        CV.quintonivelid AS "quintonivelid",
        qn.nombrequintonivel AS "nombrequintonivel",
        qn.nombrequintonivel AS "' || v_nombre_nivel5 || '"';
        RAISE NOTICE 'Agregando campos nivel 5: quinto_nivel (%) ', v_nombre_nivel5;
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
    FROM contratodatosvariables CV
    INNER JOIN contratos C ON C.iddocumento = CV.iddocumento
    LEFT JOIN cargosempleado CEm ON CV.cargo = CEm.idcargoempleado 
        AND CEm.eliminado = false 
        AND CEm.rutempresa = C.rutempresa';

    -- JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
    INNER JOIN lugarespago lp ON CV.lugarpagoid = lp.lugarpagoid 
        AND C.rutempresa = lp.empresaid';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
    INNER JOIN departamentos dp ON CV.departamentoid = dp.departamentoid 
        AND CV.lugarpagoid = dp.lugarpagoid 
        AND C.rutempresa = dp.empresaid';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
    INNER JOIN centroscosto cco ON CV.centrocosto = cco.centrocostoid 
        AND CV.lugarpagoid = cco.lugarpagoid 
        AND CV.departamentoid = cco.departamentoid 
        AND C.rutempresa = cco.empresaid';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
    INNER JOIN division div ON CV.divisionid = div.divisionid 
        AND CV.lugarpagoid = div.lugarpagoid 
        AND CV.departamentoid = div.departamentoid 
        AND CV.centrocosto = div.centrocostoid 
        AND C.rutempresa = div.empresaid';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
    INNER JOIN quinto_nivel qn ON CV.quintonivelid = qn.quintonivelid 
        AND CV.lugarpagoid = qn.lugarpagoid 
        AND CV.departamentoid = qn.departamentoid 
        AND CV.centrocosto = qn.centrocostoid 
        AND CV.divisionid = qn.divisionid 
        AND C.rutempresa = qn.empresaid';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- WHERE
    var_sql := var_sql || '
    WHERE CV.iddocumento = ' || p_iddocumento || ' 
        AND C.eliminado = false';

    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida: %', var_sql;

    -- Ejecutar consulta dinámica
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_contratodatosvariables_obtener: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_contratodatosvariables_obtener: %', SQLERRM;
END;
$BODY$;

-- =============================================
-- Autor: Haydelis Hernandez
-- Creado el: 29-04-2019
-- Migrado a PostgreSQL: 09-10-2025
-- Descripcion: Obtener división por quinto nivel (nivel 5)
-- Ejemplo: SELECT sp_division_obtenerPorNivel5('pcursor', '76270979-1', '66', '100', 'CC001', 'DIV001'); 
--          FETCH ALL IN pcursor;
-- =============================================
CREATE OR REPLACE FUNCTION public.sp_division_obtenerPorNivel5(
    p_refcursor refcursor,
    p_empresaid character varying(14),
    p_lugarpagoid character varying(14),
    p_departamentoid character varying(14),
    p_centrocostoid character varying(14),
    p_divisionid character varying(14)
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Alias para cursor
    var_cursor alias for p_refcursor;
    
    -- Variables de SQL dinámico
    var_sql TEXT;
    
BEGIN
    -- Construir consulta base
    var_sql := '
        SELECT 
            divisionid,
            nombredivision AS descripcion
        FROM 
            division
        WHERE 
            divisionid = ''' || p_divisionid || '''
            AND centrocostoid = ''' || p_centrocostoid || '''
            AND lugarpagoid = ''' || p_lugarpagoid || '''
            AND departamentoid = ''' || p_departamentoid || '''
            AND empresaid = ''' || p_empresaid || '''';
    
    -- Abrir cursor con los resultados
    OPEN var_cursor FOR EXECUTE var_sql;
    
    RETURN var_cursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_division_obtenerPorNivel5: %', SQLERRM;
END;
$BODY$;


-- FUNCTION: public.sp_documentos_apruebo_masivo(refcursor, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentos_apruebo_masivo(refcursor, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentos_apruebo_masivo(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_iddocumento integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_usuarioid varchar(10);
    var_pidDocumento integer;
    var_tipodocumento varchar(100);
    var_estado integer;
    var_idWorkFlow integer;
    var_idTipoFirma integer;
    var_nuevo_estado integer;
    var_RutFirmante varchar(10);
    var_notifnuevousuario integer;
BEGIN
    FOR var_usuarioid, var_pidDocumento, var_tipodocumento, var_estado IN
        SELECT usuarioid, iddocumento, tipodocumento, estado
        FROM tmp_aprobacion
        WHERE usuarioid = p_pusuarioid
          AND (p_iddocumento = 0 OR iddocumento = p_iddocumento)
    LOOP
        IF EXISTS (SELECT 1 FROM Contratos WHERE idDocumento = var_pidDocumento) THEN
            SELECT idTipoFirma INTO var_idTipoFirma FROM Contratos WHERE idDocumento = var_pidDocumento;

            IF var_idTipoFirma = 2 THEN
                SELECT idWF INTO var_idWorkFlow FROM Contratos WHERE idDocumento = var_pidDocumento;

                SELECT idEstadoWF INTO var_nuevo_estado
                FROM WorkflowEstadoProcesos
                WHERE idWorkflow = var_idWorkFlow AND Orden = 1;

                UPDATE Contratos
                SET idEstado = var_nuevo_estado
                WHERE idDocumento = var_pidDocumento;

                UPDATE tmp_aprobacion
                SET estado = 1
                WHERE idDocumento = var_pidDocumento;

                SELECT RutFirmante INTO var_RutFirmante
                FROM ContratoFirmantes
                WHERE idDocumento = var_pidDocumento AND idEstado = var_nuevo_estado
                ORDER BY Orden ASC
                LIMIT 1;

                SELECT notifnuevousuario INTO var_notifnuevousuario
                FROM usuarios
                WHERE usuarioid = var_RutFirmante;

                IF var_nuevo_estado = 3 AND var_notifnuevousuario = 1 THEN
                    INSERT INTO EnvioCorreos(documentoid, CodCorreo, RutUsuario)
                    VALUES (var_pidDocumento, 17, var_RutFirmante);

                    UPDATE usuarios
                    SET notifnuevousuario = 2
                    WHERE usuarioid = var_RutFirmante;
                ELSE
                    INSERT INTO EnvioCorreos(documentoid, CodCorreo, RutUsuario)
                    VALUES (var_pidDocumento, var_nuevo_estado, var_RutFirmante);
                END IF;

                INSERT INTO RegistrosAccionesUsuarios(
                    IdUsuario, FechaAccion, IP, OpcionId, Accionid, ID, Tipousuarioid
                ) VALUES (
                    var_usuarioid,
                    now(),
                    '',
                    'Documentos_Aprobar.php',
                    5,
                    var_pidDocumento,
                    0
                );
            END IF;
        END IF;
    END LOOP;

    OPEN p_refcursor FOR SELECT 0 AS "error", '' AS "mensaje";
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_documentos_elimino_masivo(
    p_refcursor refcursor,
    p_usuarioid VARCHAR(50),
    p_observacion VARCHAR(200)
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_usuarioid VARCHAR(10);
    v_iddocumento INT;
    v_tipodocumento VARCHAR(100);
    v_estado INT;
    v_count INT := 0;
BEGIN
    -- Verificar que la tabla temporal existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'tmp_aprobacion'
    ) THEN
        RAISE EXCEPTION 'La tabla temporal tmp_aprobacion no existe';
    END IF;

    -- Loop sobre los registros de la tabla temporal
    FOR v_usuarioid, v_iddocumento, v_tipodocumento, v_estado IN
        SELECT 
            ce.usuarioid,
            ce.iddocumento,
            ce.tipodocumento,
            ce.estado
        FROM tmp_aprobacion ce
        WHERE ce.usuarioid = p_usuarioid
    LOOP
        -- Verificar si el documento existe
        IF EXISTS (
            SELECT iddocumento 
            FROM contratos 
            WHERE iddocumento = v_iddocumento
        ) THEN
            -- Actualizar el contrato a estado eliminado (8)
            UPDATE contratos 
            SET 
                idestado = 8,
                observacion = p_observacion,
                fechamodificacion = NOW(),
                rutrechazo = p_usuarioid,
                fecharechazo = NOW()
            WHERE iddocumento = v_iddocumento;
            
            -- Registrar la acción del usuario
            INSERT INTO registrosaccionesusuarios(
                idusuario,
                fechaaccion,
                ip,
                opcionid,
                accionid,
                id,
                tipousuarioid
            ) VALUES (
                p_usuarioid,
                NOW(),
                '',
                'Documentos_Aprobar.php',
                10,
                v_iddocumento,
                0
            );
            
            v_count := v_count + 1;
        END IF;
    END LOOP;
    
    -- Retornar el resultado
    OPEN p_refcursor FOR
    SELECT 
        v_count AS "DocumentosEliminados",
        p_observacion AS "Observacion",
        p_usuarioid AS "UsuarioId";
    
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_documentos_listado_firmaunitaria(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentos_listado_firmaunitaria(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer);

CREATE OR REPLACE FUNCTION public.sp_documentos_listado_firmaunitaria(
	p_refcursor refcursor,
	p_tipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_iddocumento integer,
	p_idtipodocumento integer,
	p_idestadocontrato integer,
	p_idtipofirma integer,
	p_idproceso integer,
	p_lugarpagoid character varying,
	p_nombrelugarpago character varying,
	p_departamentoid character varying,
	p_nombredepartamento character varying,
	p_centrocosto character varying,
	p_nombrecentrocosto character varying,
	p_divisionid character varying,
	p_nombredivision character varying,
	p_quintonivelid character varying,
	p_nombrequintonivel character varying,
	p_empresa character varying,
	p_empleado character varying,
	p_representante character varying,
	p_rutempleado character varying,
	p_firmante character varying,
	p_fechatermino timestamp without time zone,
	p_fechainicio timestamp without time zone,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_pinicio INTEGER;
    v_pfin INTEGER;
    v_nl TEXT := CHR(13) || CHR(10);
    v_rutempleadolike VARCHAR(12);
    v_representantelike VARCHAR(100);
    v_empleadolike VARCHAR(100);
    v_centrocostoidlike VARCHAR(12);
    v_centrocostolike VARCHAR(100);
    v_lugarpagoidlike VARCHAR(12);
    v_lugarpagolike VARCHAR(100);
    v_departamentoidlike VARCHAR(12);
    v_departamentolike VARCHAR(100);
    v_divisionidlike VARCHAR(12);
    v_divisionlike VARCHAR(100);
    v_sqlstring TEXT;
    v_parametros TEXT;
    -- Variables para niveles dinámicos
    v_niveles INTEGER;
    v_rolid INTEGER;
    v_estado CHARACTER VARYING(1);
    var_log_message TEXT;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentos_listado_firmaunitaria - Usuario: ' || COALESCE(p_firmante, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol y estado del usuario (si p_firmante es un usuarioid válido)
    IF p_firmante IS NOT NULL AND p_firmante != '' THEN
        SELECT COALESCE(rolid, 2), COALESCE(idEstadoEmpleado, 'A')
        INTO v_rolid, v_estado
        FROM usuarios
        WHERE usuarioid = p_firmante;
    ELSE
        v_rolid := 2;
        v_estado := 'A';
    END IF;

    -- Calcular límites de paginación
    v_pinicio := (p_pagina - 1) * p_decuantos + 1;
    v_pfin := p_pagina * p_decuantos;
    
    -- Preparar variables LIKE
    v_rutempleadolike := '%' || TRIM(COALESCE(p_rutempleado, '')) || '%';
    v_representantelike := '%' || COALESCE(p_representante, '') || '%';
    v_empleadolike := '%' || COALESCE(p_empleado, '') || '%';
    v_lugarpagoidlike := '%' || COALESCE(p_lugarpagoid, '') || '%';
    v_lugarpagolike := '%' || COALESCE(p_nombrelugarpago, '') || '%';
    v_departamentoidlike := '%' || COALESCE(p_departamentoid, '') || '%';
    v_departamentolike := '%' || COALESCE(p_nombredepartamento, '') || '%';
    v_centrocostoidlike := '%' || COALESCE(p_centrocosto, '') || '%';
    v_centrocostolike := '%' || COALESCE(p_nombrecentrocosto, '') || '%';
    v_divisionidlike := '%' || COALESCE(p_divisionid, '') || '%';
    v_divisionlike := '%' || COALESCE(p_nombredivision, '') || '%';
    
    -- ✅ OPTIMIZACIÓN: Construir consulta directa con WITH (sin tabla temporal)
    v_sqlstring := 
        'WITH contratofirmantesTemp AS (' || v_nl ||
        '    SELECT ' || v_nl ||
        '        cf.iddocumento, ' || v_nl ||
        '        cf.idestado, ' || v_nl ||
        '        cf.rutfirmante ' || v_nl ||
        '    FROM contratofirmantes cf ' || v_nl ||
        '    WHERE cf.rutfirmante = ' || quote_literal(p_firmante) || v_nl ||
        '      AND cf.idestado IN (2, 10) ' || v_nl ||
        '      AND cf.firmado = FALSE ' || v_nl ||
        '), ' || v_nl ||
        'DocumentosTabla AS (' || v_nl ||
        'SELECT ' || v_nl ||
        '    C.iddocumento, ' || v_nl ||
        '    pl.idplantilla, ' || v_nl ||
        '    PL.idtipodoc, ' || v_nl ||
        '    C.idproceso, ' || v_nl ||
        '    CF.rutfirmante AS rutrepresentante, ' || v_nl ||
        '    P.nombre, ' || v_nl ||
        '    P.appaterno, ' || v_nl ||
        '    P.apmaterno, ' || v_nl ||
        '    (COALESCE(Per.nombre,'''') || '' '' || COALESCE(Per.appaterno,'''') || '' '' || COALESCE(Per.apmaterno,'''')) AS nombrerepresentante, ' || v_nl ||
        '    (COALESCE(P.nombre,'''') || '' '' || COALESCE(P.appaterno,'''') || '' '' || COALESCE(P.apmaterno,'''')) AS nombreempleado, ' || v_nl ||
        '    E.razonsocial, ' || v_nl ||
        '    C.idestado, ' || v_nl ||
        '    C.idtipofirma, ' || v_nl ||
        '    FD.fichaid, ' || v_nl ||
        '    CDV.cargo AS nombrecargo, ' || v_nl ||
        '    CDV.sueldobase, ' || v_nl ||
        '    CDV.fechainicio, ' || v_nl ||
        '    CDV.fechatermino, ' || v_nl ||
        '    C.fechacreacion, ' || v_nl ||
        '    CDV.rut, ' || v_nl ||
        '    C.rutempresa, ' || v_nl;
    
    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        v_sqlstring := v_sqlstring || '    CDV.lugarpagoid, ' || v_nl ||
        '    LP.nombrelugarpago, ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_sqlstring := v_sqlstring || '    CDV.departamentoid, ' || v_nl ||
        '    DP.nombredepartamento, ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_sqlstring := v_sqlstring || '    CDV.centrocosto, ' || v_nl ||
        '    CCO.nombrecentrocosto, ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 3: centrocosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_sqlstring := v_sqlstring || '    CDV.divisionid, ' || v_nl ||
        '    DIV.nombredivision, ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;
    
    IF v_niveles = 5 THEN
        v_sqlstring := v_sqlstring || '    CDV.quintonivelid, ' || v_nl ||
        '    QN.nombrequintonivel, ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;
    
    -- Continuar con campos fijos
    v_sqlstring := v_sqlstring || '    C.idwf, ' || v_nl ||
        '    C.fechaultimafirma, ' || v_nl ||
        '    ROW_NUMBER() OVER (ORDER BY C.iddocumento DESC) AS linea ' || v_nl ||
        'FROM contratos C ' || v_nl ||
        'INNER JOIN empresas E ON E.rutempresa = C.rutempresa ' || v_nl ||
        'INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento AND C.rutempresa = E.rutempresa ' || v_nl ||
        'INNER JOIN contratofirmantesTemp CF ON CF.iddocumento = C.iddocumento AND CF.idestado = C.idestado ' || v_nl ||
        'LEFT JOIN personas Per ON Per.personaid = CF.rutfirmante ' || v_nl ||
        'INNER JOIN personas P ON P.personaid = CDV.rut ' || v_nl;
    
    -- Agregar JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        v_sqlstring := v_sqlstring || 'LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa ' || v_nl;
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_sqlstring := v_sqlstring || 'LEFT JOIN departamentos DP ON DP.lugarpagoid = CDV.lugarpagoid AND DP.empresaid = C.rutempresa AND DP.departamentoid = CDV.departamentoid ' || v_nl;
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_sqlstring := v_sqlstring || 'LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.lugarpagoid = CDV.lugarpagoid AND CCO.departamentoid = CDV.departamentoid AND CCO.empresaid = C.rutempresa ' || v_nl;
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_sqlstring := v_sqlstring || 'LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto AND DIV.empresaid = C.rutempresa ' || v_nl;
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;
    
    IF v_niveles = 5 THEN
        v_sqlstring := v_sqlstring || 'LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid AND QN.empresaid = C.rutempresa ' || v_nl;
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;
    
    -- Continuar con JOINs fijos
    v_sqlstring := v_sqlstring || 'INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla ' || v_nl ||
        'LEFT JOIN fichasdocumentos FD ON C.iddocumento = FD.documentoid AND FD.idfichaorigen = 2 ' || v_nl;
    
    -- Aplicar permisos dinámicos según el nivel más alto disponible
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    
    IF v_niveles = 1 THEN
        v_sqlstring := v_sqlstring || 'INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa AND ALP.lugarpagoid = CDV.lugarpagoid AND ALP.usuarioid = ' || quote_literal(p_firmante) || v_nl;
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        v_sqlstring := v_sqlstring || 'INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = ' || quote_literal(p_firmante) || v_nl;
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        v_sqlstring := v_sqlstring || 'INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = ' || quote_literal(p_firmante) || v_nl;
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        v_sqlstring := v_sqlstring || 'INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa AND ADIV.lugarpagoid = CDV.lugarpagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = ' || quote_literal(p_firmante) || v_nl;
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        v_sqlstring := v_sqlstring || 'INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa AND AQN.lugarpagoid = CDV.lugarpagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = ' || quote_literal(p_firmante) || v_nl;
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;
    
    v_sqlstring := v_sqlstring || 'WHERE C.eliminado = FALSE ' || v_nl;
    
    -- Agregar condiciones dinámicamente (igual que antes)
    IF p_empleado != '' THEN
        v_sqlstring := v_sqlstring || ' AND ((COALESCE(P.nombre,'''') || '' '' || COALESCE(P.appaterno,'''') || '' '' || COALESCE(P.apmaterno,'''')) LIKE ' || quote_literal(v_empleadolike) || ') ' || v_nl;
    END IF;
    
    IF p_rutempleado != '' THEN
        v_sqlstring := v_sqlstring || ' AND (CDV.rut LIKE ' || quote_literal(v_rutempleadolike) || ') ' || v_nl;
    END IF;
    
    IF p_empresa != '0' AND p_empresa != '' THEN
        v_sqlstring := v_sqlstring || ' AND (C.rutempresa = ' || quote_literal(p_empresa) || ') ' || v_nl;
    END IF;
    
    IF p_iddocumento != 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.iddocumento = ' || p_iddocumento || v_nl;
    END IF;
    
    IF p_idtipodocumento != 0 THEN
        v_sqlstring := v_sqlstring || ' AND PL.idtipodoc = ' || p_idtipodocumento || v_nl;
    END IF;
    
    IF p_idestadocontrato > 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.idestado = ' || p_idestadocontrato || v_nl;
    END IF;
    
    IF p_idestadocontrato < 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.idestado IN (2,3,6,8,9,10) ' || v_nl;
    END IF;
    
    IF p_idestadocontrato = 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.idestado IN (2,3,10) ' || v_nl;
    END IF;
    
    IF p_idtipofirma != 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.idtipofirma = ' || p_idtipofirma || v_nl;
    END IF;
    
    IF p_idproceso != 0 THEN
        v_sqlstring := v_sqlstring || ' AND C.idproceso = ' || p_idproceso || v_nl;
    END IF;
    
    IF p_fechatermino IS NOT NULL THEN
        v_sqlstring := v_sqlstring || ' AND CDV.fechatermino = ' || quote_literal(p_fechatermino) || v_nl;
    END IF;
    
    IF p_fechainicio IS NOT NULL THEN
        v_sqlstring := v_sqlstring || ' AND CDV.fechainicio = ' || quote_literal(p_fechainicio) || v_nl;
    END IF;
    
    
    -- Filtros dinámicos para cada nivel disponible
    IF v_niveles >= 1 AND p_lugarpagoid != '' THEN
        v_sqlstring := v_sqlstring || ' AND CDV.lugarpagoid = ' || quote_literal(p_lugarpagoid) || v_nl;
    END IF;
    
    IF v_niveles >= 1 AND p_nombrelugarpago != '' THEN
        v_sqlstring := v_sqlstring || ' AND (LP.nombrelugarpago LIKE ' || quote_literal(v_lugarpagolike) || ') ' || v_nl;
    END IF;
    
    IF v_niveles >= 2 AND p_departamentoid != '' THEN
        v_sqlstring := v_sqlstring || ' AND CDV.departamentoid = ' || quote_literal(p_departamentoid) || v_nl;
    END IF;
    
    IF v_niveles >= 2 AND p_nombredepartamento != '' THEN
        v_sqlstring := v_sqlstring || ' AND (DP.nombredepartamento LIKE ' || quote_literal(v_departamentolike) || ') ' || v_nl;
    END IF;
    
    IF v_niveles >= 3 AND p_centrocosto != '' THEN
        v_sqlstring := v_sqlstring || ' AND CDV.centrocosto = ' || quote_literal(p_centrocosto) || v_nl;
    END IF;
    
    IF v_niveles >= 3 AND p_nombrecentrocosto != '' THEN
        v_sqlstring := v_sqlstring || ' AND (CCO.nombrecentrocosto LIKE ' || quote_literal(v_centrocostolike) || ') ' || v_nl;
    END IF;
    
    IF v_niveles >= 4 AND p_divisionid != '' THEN
        v_sqlstring := v_sqlstring || ' AND CDV.divisionid = ' || quote_literal(p_divisionid) || v_nl;
    END IF;
    
    IF v_niveles >= 4 AND p_nombredivision != '' THEN
        v_sqlstring := v_sqlstring || ' AND (DIV.nombredivision LIKE ' || quote_literal(v_divisionlike) || ') ' || v_nl;
    END IF;
    
    IF v_niveles = 5 AND p_quintonivelid != '' THEN
        v_sqlstring := v_sqlstring || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid) || v_nl;
    END IF;
    
    IF v_niveles = 5 AND p_nombrequintonivel != '' THEN
        v_sqlstring := v_sqlstring || ' AND (QN.nombrequintonivel LIKE ' || quote_literal('%' || COALESCE(p_nombrequintonivel, '') || '%') || ') ' || v_nl;
    END IF;
    
    -- Completar la consulta con el SELECT final
    v_sqlstring := v_sqlstring || 
        ') ' || v_nl ||
        'SELECT ' || v_nl ||
        '    DT.iddocumento AS "idDocumento", ' || v_nl ||
        '    TD.idtipodoc AS "idTipoDoc", ' || v_nl ||
        '    TD.nombretipodoc AS "NombreTipoDoc", ' || v_nl ||
        '    P.idproceso AS "idProceso", ' || v_nl ||
        '    P.descripcion AS "Proceso", ' || v_nl ||
        '    DT.razonsocial AS "RazonSocial", ' || v_nl;
    
    -- Agregar campos dinámicos en el SELECT final
    IF v_niveles >= 1 THEN
        v_sqlstring := v_sqlstring || '    DT.lugarpagoid AS "LugarPagoid", ' || v_nl ||
        '    DT.nombrelugarpago AS "nombrelugarpago", ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 1 en SELECT final: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_sqlstring := v_sqlstring || '    DT.departamentoid AS "Departamentoid", ' || v_nl ||
        '    DT.nombredepartamento AS "nombredepartamento", ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 2 en SELECT final: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_sqlstring := v_sqlstring || '    DT.centrocosto AS "CentroCosto", ' || v_nl ||
        '    DT.nombrecentrocosto AS "nombreCentroCosto", ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 3 en SELECT final: centrocosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_sqlstring := v_sqlstring || '    DT.divisionid AS "Divisionid", ' || v_nl ||
        '    DT.nombredivision AS "nombredivision", ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 4 en SELECT final: division';
    END IF;
    
    IF v_niveles = 5 THEN
        v_sqlstring := v_sqlstring || '    DT.quintonivelid AS "QuintoNivelid", ' || v_nl ||
        '    DT.nombrequintonivel AS "nombrequintonivel", ' || v_nl;
        RAISE NOTICE 'Agregando campo nivel 5 en SELECT final: quinto_nivel';
    END IF;
    
    -- Continuar con campos fijos
    v_sqlstring := v_sqlstring || '    DT.idestado AS "idEstado", ' || v_nl ||
        '    CE.descripcion AS "Estado", ' || v_nl ||
        '    FT.descripcion AS "Firma", ' || v_nl ||
        '    DT.rutrepresentante AS "RutRepresentante", ' || v_nl ||
        '    DT.nombrerepresentante AS "NombreRepresentante", ' || v_nl ||
        '    DT.rut AS "RutEmpleado", ' || v_nl ||
        '    DT.nombre AS "nombre", ' || v_nl ||
        '    DT.appaterno AS "appaterno", ' || v_nl ||
        '    DT.apmaterno AS "apmaterno", ' || v_nl ||
        '    DT.nombreempleado AS "NombreEmpleado", ' || v_nl ||
        '    DT.nombrecargo AS "Cargo", ' || v_nl ||
        '    DT.sueldobase AS "SueldoBase", ' || v_nl ||
        '    TO_CHAR(DT.fechainicio, ''DD-MM-YYYY'') AS "FechaInicio", ' || v_nl ||
        '    TO_CHAR(DT.fechatermino, ''DD-MM-YYYY'') AS "FechaTermino", ' || v_nl ||
        '    TO_CHAR(DT.fechacreacion, ''DD-MM-YYYY'') AS "FechaCreacion", ' || v_nl ||
        '    TO_CHAR(DT.fechaultimafirma, ''DD-MM-YYYY'') AS "FechaUltimaFirma", ' || v_nl ||
        '    1 AS "Semaforo", ' || v_nl ||
        '    WEP.diasmax AS "DiasEstadoActual", ' || v_nl ||
        '    DT.idwf AS "idWF", ' || v_nl ||
        '    DT.linea AS "Rownum" ' || v_nl ||
        'FROM DocumentosTabla DT ' || v_nl ||
        'INNER JOIN tipodocumentos TD ON DT.idtipodoc = TD.idtipodoc ' || v_nl ||
        'INNER JOIN procesos P ON P.idproceso = DT.idproceso ' || v_nl ||
        'INNER JOIN contratosestados CE ON CE.idestado = DT.idestado ' || v_nl ||
        'INNER JOIN firmastipos FT ON FT.idtipofirma = DT.idtipofirma ' || v_nl ||
        'LEFT JOIN workflowestadoprocesos WEP ON DT.idwf = WEP.idworkflow AND DT.idestado = WEP.idestadowf ' || v_nl ||
        'WHERE DT.linea BETWEEN ' || v_pinicio || ' AND ' || v_pfin;
    
    IF p_debug = 1 THEN
        RAISE NOTICE '%', v_sqlstring;
    END IF;
    
    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida (primeros 500 caracteres): %', LEFT(v_sqlstring, 500);
    
    -- Ejecutar consulta dinámica y abrir cursor
    RAISE NOTICE 'Ejecutando consulta de listado con paginación';
    OPEN p_refcursor FOR EXECUTE v_sqlstring;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_documentos_listado_firmaunitaria: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_documentos_listado_firmaunitaria: %', SQLERRM;
END;
$BODY$;

-- FUNCTION: public.sp_documentos_obtenerencabezadosvariables(refcursor)

-- DROP FUNCTION IF EXISTS public.sp_documentos_obtenerencabezadosvariables(refcursor);

CREATE OR REPLACE FUNCTION public.sp_documentos_obtenerencabezadosvariables(
	p_refcursor refcursor)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql text;
    v_niveles integer;
    v_nombre_nivel1 varchar(50);
    v_nombre_nivel2 varchar(50);
    v_nombre_nivel3 varchar(50);
    v_nombre_nivel4 varchar(50);
    v_nombre_nivel5 varchar(50);
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener nombres de niveles desde niveles_estructura
    IF v_niveles >= 1 THEN
        SELECT nombre INTO v_nombre_nivel1 FROM niveles_estructura WHERE nivel = 1 AND activo = true;
        RAISE NOTICE 'Nombre nivel 1: %', v_nombre_nivel1;
    END IF;
    
    IF v_niveles >= 2 THEN
        SELECT nombre INTO v_nombre_nivel2 FROM niveles_estructura WHERE nivel = 2 AND activo = true;
        RAISE NOTICE 'Nombre nivel 2: %', v_nombre_nivel2;
    END IF;
    
    IF v_niveles >= 3 THEN
        SELECT nombre INTO v_nombre_nivel3 FROM niveles_estructura WHERE nivel = 3 AND activo = true;
        RAISE NOTICE 'Nombre nivel 3: %', v_nombre_nivel3;
    END IF;
    
    IF v_niveles >= 4 THEN
        SELECT nombre INTO v_nombre_nivel4 FROM niveles_estructura WHERE nivel = 4 AND activo = true;
        RAISE NOTICE 'Nombre nivel 4: %', v_nombre_nivel4;
    END IF;
    
    IF v_niveles = 5 THEN
        SELECT nombre INTO v_nombre_nivel5 FROM niveles_estructura WHERE nivel = 5 AND activo = true;
        RAISE NOTICE 'Nombre nivel 5: %', v_nombre_nivel5;
    END IF;

    -- Construir SELECT dinámico con niveles
    var_sql := 'SELECT ';

    -- Agregar niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '1 AS "' || v_nombre_nivel1 || '", ';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '1 AS "' || v_nombre_nivel2 || '", ';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '1 AS "' || v_nombre_nivel3 || '", ';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '1 AS "' || v_nombre_nivel4 || '", ';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '1 AS "' || v_nombre_nivel5 || '", ';
    END IF;

    -- Agregar campos base (siempre presentes)
    var_sql := var_sql || '
            1 AS "FechaDocumento",
            1 AS "Afp",
            1 AS "Banco",
            1 AS "Cargo",
            1 AS "Colacion",
            1 AS "FechaIngreso",
            1 AS "FechaInicio",
            1 AS "FechaTermino",
            1 AS "Horas",
            1 AS "Jornada",
            1 AS "Movilizacion",
            1 AS "NombreContactoEmergencia",
            1 AS "TipoCuenta",
            1 AS "NroCuenta",
            1 AS "Salud",
            1 AS "SueldoBase",
            1 AS "Telefono",
            1 AS "TelefonoContactoEmergencia",
            1 AS "Texto1",
            1 AS "Texto2",
            1 AS "Texto3",
            1 AS "Texto4",
            1 AS "Texto5",
            1 AS "Texto6",
            1 AS "Texto7",
            1 AS "Texto8",
            1 AS "Texto9",
            1 AS "Texto10",
            1 AS "Texto11",
            1 AS "Texto12",
            1 AS "Texto13",
            1 AS "Texto14",
            1 AS "Texto15",
            1 AS "Texto16",
            1 AS "Texto17",
            1 AS "Texto18",
            1 AS "Texto19",
            1 AS "Texto20"
        LIMIT 1';

    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida: %', var_sql;

    -- Ejecutar consulta dinámica
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR en sp_documentos_obtenerencabezadosvariables: %', SQLERRM;
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- =============================================
-- Autor: Haydelis Hernandez
-- Creado el: 11-03-2020
-- Migrado a PostgreSQL: 12-01-2025
-- Descripcion: Obtiene los contratos de un arreglo completo 
-- Ejemplo: SELECT sp_documentos_obtenerMultiple('pcursor', '8029,8028'); FETCH ALL IN pcursor;
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_documentos_obtenerMultiple(
    p_refcursor refcursor,
    p_idDocumentos TEXT
)
RETURNS refcursor
LANGUAGE plpgsql
COST 100
VOLATILE
PARALLEL UNSAFE
AS $BODY$
BEGIN
    -- Abrir cursor con la consulta
    OPEN p_refcursor FOR
    SELECT	
        c.iddocumento AS "idDocumento",
        td.nombretipodoc AS "NombreTipoDoc",
        ce.descripcion AS "Estado",
        c.doccode AS "DocCode"
    FROM contratos c
    INNER JOIN plantillas pl ON pl.idplantilla = c.idplantilla
    INNER JOIN tipodocumentos td ON pl.idtipodoc = td.idtipodoc
    INNER JOIN contratosestados ce ON ce.idestado = c.idestado
    WHERE c.iddocumento::VARCHAR = ANY(string_to_array(p_idDocumentos, ','))
    ORDER BY c.iddocumento;
    
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_documentos_obtenerporaprobar(refcursor, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentos_obtenerporaprobar(refcursor, integer);

CREATE OR REPLACE FUNCTION public.sp_documentos_obtenerporaprobar(
	p_refcursor refcursor,
	p_iddocumento integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$

BEGIN
    OPEN p_refcursor FOR
        SELECT 
            CAST(C.iddocumento AS INTEGER) AS "idDocumento",
            CAST(TD.nombretipodoc AS VARCHAR(255)) AS "NombreTipoDoc"
        FROM contratos C
        INNER JOIN tipogeneracion TG ON TG.idtipogeneracion = C.idtipogeneracion
        INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla
        INNER JOIN tipodocumentos TD ON TD.idtipodoc = PL.idtipodoc
        INNER JOIN contratosestados EW ON EW.idestado = C.idestado
        INNER JOIN workflowproceso WP ON C.idwf = WP.idwf
        INNER JOIN firmastipos F ON F.idtipofirma = C.idtipofirma
        INNER JOIN procesos P ON P.idproceso = C.idproceso
        WHERE C.iddocumento = p_iddocumento;
    
    RETURN p_refcursor;
END;
$BODY$;

CREATE OR REPLACE FUNCTION public.sp_documentos_obtenerVariablesRepresentante_conRutSinDocumento(
 	p_refcursor refcursor,
    p_firmante character varying(10)
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Alias para el cursor de retorno
    var_cursor alias for p_refcursor;
BEGIN
    -- Validar parámetro requerido
    IF p_firmante IS NULL OR p_firmante = '' THEN
        RAISE EXCEPTION 'El parámetro p_firmante es requerido';
    END IF;

    -- Abrir cursor con los resultados
    OPEN var_cursor FOR
        SELECT 
            P.personaid AS "Rut",
            P.nombre || ' ' || P.appaterno || ' ' || COALESCE(P.apmaterno, '') AS "Nombre",
            P.direccion,
            P.direccion AS "Direccion",
            P.comuna,
            P.ciudad,
            COALESCE(P.Direccion, '') || ' ' || COALESCE(P.Comuna, '') || ' ' || COALESCE(P.Ciudad, '') AS "DireccionCompleta",
            P.correo,
            P.nacionalidad,
            P.nacionalidad AS "Nacionalidad",
            TO_CHAR(P.fechanacimiento, 'DD-MM-YYYY') AS "FechaNacimiento",
            COALESCE(ec.Descripcion, '') AS estadocivil,
            F.Profesion,
            F.Cargo 
        FROM Firmantes CF 
            INNER JOIN Personas P ON CF.RutUsuario = P.personaid
            LEFT JOIN Firmantes F ON F.RutUsuario = P.personaid
            LEFT JOIN EstadoCivil ec ON P.estadocivil = ec.idEstadoCivil
        WHERE 
            CF.RutUsuario = p_firmante
        LIMIT 1;
    
    RETURN var_cursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en sp_documentos_obtenerVariablesRepresentante_conRutSinDocumento: %', SQLERRM;
END;
$BODY$;-- FUNCTION: public.sp_documentos_total_firmaunitaria(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentos_total_firmaunitaria(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer);

CREATE OR REPLACE FUNCTION public.sp_documentos_total_firmaunitaria(
	p_cursor refcursor,
	p_tipo_usuario_id integer,
	p_pagina integer,
	p_de_cuantos numeric,
	p_id_documento integer,
	p_id_tipo_documento integer,
	p_id_estado_contrato integer,
	p_id_tipo_firma integer,
	p_id_proceso integer,
	p_lugar_pago_id character varying,
	p_nombre_lugar_pago character varying,
	p_departamento_id character varying,
	p_nombre_departamento character varying,
	p_centro_costo character varying,
	p_nombre_centro_costo character varying,
	p_division_id character varying,
	p_nombre_division character varying,
    p_quintonivelid character varying,
    p_nombrequintonivel character varying,
	p_empresa character varying,
	p_empleado character varying,
	p_representante character varying,
	p_rut_empleado character varying,
	p_firmante character varying,
	p_fecha_termino timestamp without time zone,
	p_fecha_inicio timestamp without time zone,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_total INTEGER;
    v_total_orig INTEGER;
    v_total_reg DECIMAL(9,2);
    
    v_p_inicio INTEGER;
    v_p_fin INTEGER;
    v_nl CHAR(2) := CHR(13) || CHR(10);
    
    v_rut_empleado_like VARCHAR(12);
    v_representante_like VARCHAR(100);
    v_empresa_like VARCHAR(100);
    v_empleado_like VARCHAR(100);
    v_centro_costo_id_like VARCHAR(12);
    v_centro_costo_like VARCHAR(100);
    v_lugar_pago_id_like VARCHAR(12);
    v_lugar_pago_like VARCHAR(100);
    v_departamento_id_like VARCHAR(12);
    v_departamento_like VARCHAR(100);
    v_division_id_like VARCHAR(12);
    v_division_like VARCHAR(100);
    v_quintonivel_id_like VARCHAR(12);
    v_quintonivel_like VARCHAR(100);
    v_sql_string TEXT;
    v_decimal DECIMAL(9,2);
    v_niveles INTEGER;
    v_rolid INTEGER;
BEGIN
    v_p_inicio := (p_pagina - 1) * p_de_cuantos + 1;
    v_p_fin := p_pagina * p_de_cuantos;
    
    -- ✅ OPTIMIZACIÓN: Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles para firma unitaria totales: %', v_niveles;
    
    -- Obtener rol del usuario para permisos
    SELECT rolid INTO v_rolid FROM usuarios WHERE usuarioid = p_firmante;
    
    v_rut_empleado_like := '%' || COALESCE(p_rut_empleado, '') || '%';
    v_representante_like := '%' || COALESCE(p_representante, '') || '%';
    v_empleado_like := '%' || COALESCE(p_empleado, '') || '%';
    v_empresa_like := '%' || COALESCE(p_empresa, '') || '%';
    v_lugar_pago_id_like := '%' || COALESCE(p_lugar_pago_id, '') || '%';
    v_lugar_pago_like := '%' || COALESCE(p_nombre_lugar_pago, '') || '%';
    v_departamento_id_like := '%' || COALESCE(p_departamento_id, '') || '%';
    v_departamento_like := '%' || COALESCE(p_nombre_departamento, '') || '%';
    v_centro_costo_id_like := '%' || COALESCE(p_centro_costo, '') || '%';
    v_centro_costo_like := '%' || COALESCE(p_nombre_centro_costo, '') || '%';
    v_division_id_like := '%' || COALESCE(p_division_id, '') || '%';
    v_division_like := '%' || COALESCE(p_nombre_division, '') || '%';
    v_quintonivel_id_like := '%' || COALESCE(p_quintonivelid, '') || '%';
    v_quintonivel_like := '%' || COALESCE(p_nombrequintonivel, '') || '%';
    
    -- ✅ OPTIMIZACIÓN: Construir consulta directa con WITH (sin tabla temporal)
    v_sql_string := '
        WITH contratofirmantesTemp AS (
            SELECT 
                cf.iddocumento,
                cf.idestado,
                cf.rutfirmante
            FROM contratofirmantes cf
            WHERE cf.rutfirmante = ' || quote_literal(p_firmante) || '
            AND cf.idestado IN (2,10)
            AND cf.firmado = FALSE
        ),
        DocumentosTabla AS (
            SELECT 
                C.iddocumento, 
                pl.idplantilla, 
                pl.idtipodoc,
                C.idproceso,    
                CF.rutfirmante AS rut_representante,
                P.nombre,
                P.appaterno,
                P.apmaterno,
                (COALESCE(Per.nombre, '''') || '' '' || COALESCE(Per.appaterno, '''') || '' '' || COALESCE(Per.apmaterno, '''')) AS nombre_representante,
                (COALESCE(P.nombre, '''') || '' '' || COALESCE(P.appaterno, '''') || '' '' || COALESCE(P.apmaterno, '''')) AS nombre_empleado,
                E.razonsocial,
                C.idestado, 
                C.idtipofirma,
                FD.fichaid,
                CDV.cargo AS nombre_cargo,
                CDV.sueldobase,
                CDV.fechainicio,
                CDV.fechatermino,
                C.fechacreacion,
                CDV.rut, 
                C.rutempresa';
    
    -- Agregar campos de niveles dinámicamente al SELECT
    IF v_niveles >= 1 THEN
        v_sql_string := v_sql_string || ',
                CDV.lugarpagoid,
                LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campo nivel 1 en SELECT: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_sql_string := v_sql_string || ',
                CDV.departamentoid,
                DP.nombredepartamento';
        RAISE NOTICE 'Agregando campo nivel 2 en SELECT: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_sql_string := v_sql_string || ',
                CDV.centrocosto,
                CCO.nombrecentrocosto';
        RAISE NOTICE 'Agregando campo nivel 3 en SELECT: centrocosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_sql_string := v_sql_string || ',
                CDV.divisionid,
                DIV.nombredivision';
        RAISE NOTICE 'Agregando campo nivel 4 en SELECT: division';
    END IF;
    
    IF v_niveles = 5 THEN
        v_sql_string := v_sql_string || ',
                CDV.quintonivelid,
                QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campo nivel 5 en SELECT: quinto_nivel';
    END IF;
    
    -- Continuar con campos fijos
    v_sql_string := v_sql_string || ',
                C.idwf, 
                C.fechaultimafirma,
                ROW_NUMBER() OVER (ORDER BY C.iddocumento DESC) AS linea
            FROM contratos C     
            INNER JOIN empresas E ON E.rutempresa = C.rutempresa    
            INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento AND C.rutempresa = E.rutempresa
            INNER JOIN contratofirmantesTemp CF ON CF.iddocumento = C.iddocumento AND CF.idestado = C.idestado
            LEFT JOIN personas Per ON Per.personaid = CF.rutfirmante
            INNER JOIN personas P ON P.personaid = CDV.rut
            INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla
            LEFT JOIN fichasdocumentos FD ON C.iddocumento = FD.documentoid AND FD.idfichaorigen = 2
            ';
    
    -- ✅ OPTIMIZACIÓN: JOINs dinámicos por nivel (solo agregar los que están disponibles)
    IF v_niveles >= 1 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN departamentos DP ON DP.lugarpagoid = CDV.lugarpagoid AND DP.empresaid = C.rutempresa AND DP.departamentoid = CDV.departamentoid';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.empresaid = C.rutempresa AND CCO.lugarpagoid = CDV.lugarpagoid AND CCO.departamentoid = CDV.departamentoid';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.empresaid = C.rutempresa AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.empresaid = C.rutempresa AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;
    
    -- ✅ CORRECCIÓN: Permisos dinámicos por nivel usando INNER JOIN (antes del WHERE)
    IF v_rolid != 2 THEN
        IF v_niveles = 1 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa AND ALP.lugarpagoid = CDV.lugarpagoid AND ALP.usuarioid = ' || quote_literal(p_firmante);
            RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
        ELSIF v_niveles = 2 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = ' || quote_literal(p_firmante);
            RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
        ELSIF v_niveles = 3 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = ' || quote_literal(p_firmante);
            RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
        ELSIF v_niveles = 4 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa AND ADIV.lugarpagoid = CDV.lugarpagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = ' || quote_literal(p_firmante);
            RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
        ELSIF v_niveles = 5 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa AND AQN.lugarpagoid = CDV.lugarpagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = ' || quote_literal(p_firmante);
            RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
        END IF;
    ELSE
        RAISE NOTICE 'Usuario público (rol 2) - sin restricciones de acceso por niveles';
    END IF;
    
    v_sql_string := v_sql_string || ' WHERE C.eliminado = FALSE';
    
    -- Usar quote_literal para evitar problemas con parámetros dinámicos
    IF p_empleado != '' THEN
        v_sql_string := v_sql_string || ' AND ((COALESCE(P.nombre, '''') || '' '' || COALESCE(P.appaterno, '''') || '' '' || COALESCE(P.apmaterno, '''')) LIKE ' || quote_literal(v_empleado_like) || ')';
    END IF;
    
    IF p_rut_empleado != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.rut LIKE ' || quote_literal(v_rut_empleado_like);
    END IF;
    
    IF p_empresa != '0' AND p_empresa != '' THEN
        v_sql_string := v_sql_string || ' AND C.rutempresa = ' || quote_literal(p_empresa);
    END IF;
    
    IF p_representante != '' THEN
        v_sql_string := v_sql_string || ' AND CF.rutfirmante LIKE ' || quote_literal(v_representante_like);
    END IF;
    
    IF p_id_documento != 0 THEN
        v_sql_string := v_sql_string || ' AND C.iddocumento = ' || p_id_documento;
    END IF;
    
    IF p_id_tipo_documento != 0 THEN
        v_sql_string := v_sql_string || ' AND PL.idtipodoc = ' || p_id_tipo_documento;
    END IF;
    
    IF p_id_estado_contrato > 0 THEN
        v_sql_string := v_sql_string || ' AND C.idestado = ' || p_id_estado_contrato;
    END IF;
    
    IF p_id_estado_contrato < 0 THEN
        v_sql_string := v_sql_string || ' AND C.idestado IN (2,3,6,8,9,10)';
    END IF;
    
    IF p_id_estado_contrato = 0 THEN
        v_sql_string := v_sql_string || ' AND C.idestado IN (2,3,10)';
    END IF;
    
    IF p_id_tipo_firma != 0 THEN
        v_sql_string := v_sql_string || ' AND C.idtipofirma = ' || p_id_tipo_firma;
    END IF;
    
    IF p_id_proceso != 0 THEN
        v_sql_string := v_sql_string || ' AND C.idproceso = ' || p_id_proceso;
    END IF;
    
    IF p_fecha_termino IS NOT NULL THEN
        v_sql_string := v_sql_string || ' AND CDV.fechatermino = ' || quote_literal(p_fecha_termino);
    END IF;
    
    IF p_fecha_inicio IS NOT NULL THEN
        v_sql_string := v_sql_string || ' AND CDV.fechainicio = ' || quote_literal(p_fecha_inicio);
    END IF;
    
    -- ✅ OPTIMIZACIÓN: Filtros dinámicos por nivel (solo aplicar si el nivel está disponible)
    IF v_niveles >= 1 AND p_lugar_pago_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.lugarpagoid = ' || quote_literal(p_lugar_pago_id);
        RAISE NOTICE 'Agregando filtro nivel 1: lugarpagoid = %', p_lugar_pago_id;
    END IF;
    
    IF v_niveles >= 1 AND p_nombre_lugar_pago != '' THEN
        v_sql_string := v_sql_string || ' AND LP.nombrelugarpago LIKE ' || quote_literal(v_lugar_pago_like);
        RAISE NOTICE 'Agregando filtro nivel 1: nombrelugarpago = %', p_nombre_lugar_pago;
    END IF;
    
    IF v_niveles >= 2 AND p_departamento_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.departamentoid = ' || quote_literal(p_departamento_id);
        RAISE NOTICE 'Agregando filtro nivel 2: departamentoid = %', p_departamento_id;
    END IF;
    
    IF v_niveles >= 2 AND p_nombre_departamento != '' THEN
        v_sql_string := v_sql_string || ' AND DP.nombredepartamento LIKE ' || quote_literal(v_departamento_like);
        RAISE NOTICE 'Agregando filtro nivel 2: nombredepartamento = %', p_nombre_departamento;
    END IF;
    
    IF v_niveles >= 3 AND p_centro_costo != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.centrocosto = ' || quote_literal(p_centro_costo);
        RAISE NOTICE 'Agregando filtro nivel 3: centrocosto = %', p_centro_costo;
    END IF;
    
    IF v_niveles >= 3 AND p_nombre_centro_costo != '' THEN
        v_sql_string := v_sql_string || ' AND CCO.nombrecentrocosto LIKE ' || quote_literal(v_centro_costo_like);
        RAISE NOTICE 'Agregando filtro nivel 3: nombrecentrocosto = %', p_nombre_centro_costo;
    END IF;
    
    IF v_niveles >= 4 AND p_division_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.divisionid = ' || quote_literal(p_division_id);
        RAISE NOTICE 'Agregando filtro nivel 4: divisionid = %', p_division_id;
    END IF;
    
    IF v_niveles >= 4 AND p_nombre_division != '' THEN
        v_sql_string := v_sql_string || ' AND DIV.nombredivision LIKE ' || quote_literal(v_division_like);
        RAISE NOTICE 'Agregando filtro nivel 4: nombredivision = %', p_nombre_division;
    END IF;
    
    IF v_niveles = 5 AND p_quintonivelid != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid);
        RAISE NOTICE 'Agregando filtro nivel 5: quintonivelid = %', p_quintonivelid;
    END IF;
    
    IF v_niveles = 5 AND p_nombrequintonivel != '' THEN
        v_sql_string := v_sql_string || ' AND QN.nombrequintonivel LIKE ' || quote_literal(v_quintonivel_like);
        RAISE NOTICE 'Agregando filtro nivel 5: nombrequintonivel = %', p_nombrequintonivel;
    END IF;
    
    v_sql_string := v_sql_string || '
        ) SELECT COUNT(*) FROM DocumentosTabla';
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'SQL de totales firma unitaria: %', v_sql_string;
    END IF;
    
    -- Ejecutar la consulta dinámica sin USING ya que usamos quote_literal
    EXECUTE v_sql_string INTO v_total_orig;
    
    RAISE NOTICE 'Total de registros encontrados para firma unitaria: %', v_total_orig;
    
    v_total_reg := (v_total_orig::DECIMAL / p_de_cuantos);
    v_decimal := v_total_reg - FLOOR(v_total_reg);
    
    IF v_decimal > 0 THEN
        v_total := FLOOR(v_total_reg) + 1;
    ELSE
        v_total := FLOOR(v_total_reg);
    END IF;
    
    -- Asegurar mínimo 1 página
    IF v_total < 1 THEN
        v_total := 1;
    END IF;
    
    v_total_reg := v_total_reg * p_de_cuantos;
    
    -- Abrir el cursor con el resultado
    OPEN p_cursor FOR
    SELECT v_total AS total, v_total_reg::INTEGER AS totalreg;
    
    -- Retornar el cursor
    RETURN p_cursor;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error en sp_documentos_total_firmaunitaria: %', SQLERRM;
    OPEN p_cursor FOR SELECT 1 AS total, 0 AS totalreg;
    RETURN p_cursor;
END;
$BODY$;

-- FUNCTION: public.sp_documentosporaprobar_listado(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_documentosporaprobar_listado(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_documentosporaprobar_listado(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer DEFAULT 0,
	p_prutempresa character varying DEFAULT ''::character varying,
	p_prutempleado character varying DEFAULT ''::character varying,
	p_pnombreempleado character varying DEFAULT ''::character varying,
	p_plugarpagoid character varying DEFAULT ''::character varying,
	p_pnombrelugarpago character varying DEFAULT ''::character varying,
	p_pdepartamentoid character varying DEFAULT ''::character varying,
	p_pnombredepartamento character varying DEFAULT ''::character varying,
	p_pcentrocosto character varying DEFAULT ''::character varying,
	p_pnombrecentrocosto character varying DEFAULT ''::character varying,
	p_pdivisionid character varying DEFAULT ''::character varying,
	p_pnombredivision character varying DEFAULT ''::character varying,
	p_pquintonivelid character varying DEFAULT ''::character varying,
	p_pnombrequintonivel character varying DEFAULT ''::character varying,
	p_pusuarioid character varying DEFAULT ''::character varying,
	p_pfichaid integer DEFAULT 0,
	p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql    text;
    v_rolid    integer;
    v_inicio   integer := (p_pagina - 1) * p_decuantos + 1;
    v_fin      integer := p_pagina * p_decuantos;
    v_niveles  integer;
BEGIN
    -- Obtener rol del usuario
    SELECT rolid INTO v_rolid FROM usuarios WHERE usuarioid = p_pusuarioid;
    
    -- Obtener niveles disponibles
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Log: mostrar información de niveles y parámetros
    RAISE NOTICE '=== INICIO DEBUG SP_DOCUMENTOSPORAPROBAR_LISTADO ===';
    RAISE NOTICE 'v_niveles: %', v_niveles;
    RAISE NOTICE 'p_pusuarioid: %', p_pusuarioid;
    RAISE NOTICE 'p_ptipousuarioid: %', p_ptipousuarioid;
    RAISE NOTICE 'v_rolid: %', v_rolid;
    RAISE NOTICE 'p_plugarpagoid: %', p_plugarpagoid;
    RAISE NOTICE 'p_pdepartamentoid: %', p_pdepartamentoid;
    RAISE NOTICE 'p_pcentrocosto: %', p_pcentrocosto;
    RAISE NOTICE 'p_pdivisionid: %', p_pdivisionid;
    RAISE NOTICE 'p_pquintonivelid: %', p_pquintonivelid;

    -- Construir consulta dinámica
    var_sql :=
    'WITH DocumentosTabla AS (
       SELECT
         C.idDocumento,
         PL.idPlantilla,
         PL.idTipoDoc,
         C.idproceso,
         C.idestado,
         C.idtipofirma,
         C.FechaCreacion,
         C.FechaUltimaFirma,
         CDV.Rut,
         C.RutEmpresa,
         C.idwf';
    
    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', CDV.LugarPagoid, LP.nombrelugarpago';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', CDV.departamentoid, DEP.nombredepartamento';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', CDV.centrocosto, CCO.nombrecentrocosto';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', CDV.divisionid, DIV.nombredivision';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', CDV.quintonivelid, QN.nombrequintonivel';
    END IF;
    
    var_sql := var_sql || ', ROW_NUMBER() OVER (ORDER BY C.idDocumento DESC) AS linea
       FROM contratos C
       INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
       INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc
         AND T.tipousuarioid = ' || quote_literal(p_ptipousuarioid) || '
       INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento';
    
    -- JOINs de niveles dinámicos
    RAISE NOTICE '=== APLICANDO JOINs DINAMICOS ===';
    
    IF v_niveles >= 1 THEN
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
        var_sql := var_sql || '
       LEFT JOIN lugarespago LP ON LP.empresaid = C.RutEmpresa
         AND LP.lugarpagoid = CDV.LugarPagoid';
    END IF;

    IF v_niveles >= 2 THEN
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
        var_sql := var_sql || '
       LEFT JOIN departamentos DEP ON DEP.empresaid = C.RutEmpresa
         AND DEP.lugarpagoid = CDV.LugarPagoid
         AND DEP.departamentoid = CDV.departamentoid';
    END IF;

    IF v_niveles >= 3 THEN
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
        var_sql := var_sql || '
       LEFT JOIN centroscosto CCO ON CCO.empresaid = C.RutEmpresa
         AND CCO.lugarpagoid = CDV.LugarPagoid
         AND CCO.departamentoid = CDV.departamentoid
         AND CCO.centrocostoid = CDV.centrocosto';
    END IF;

    IF v_niveles >= 4 THEN
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
        var_sql := var_sql || '
       LEFT JOIN division DIV ON DIV.empresaid = C.RutEmpresa
         AND DIV.lugarpagoid = CDV.LugarPagoid
         AND DIV.departamentoid = CDV.departamentoid
         AND DIV.centrocostoid = CDV.centrocosto
         AND DIV.divisionid = CDV.divisionid';
    END IF;

    IF v_niveles = 5 THEN
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
        var_sql := var_sql || '
       LEFT JOIN quinto_nivel QN ON QN.empresaid = C.RutEmpresa
         AND QN.lugarpagoid = CDV.LugarPagoid
         AND QN.departamentoid = CDV.departamentoid
         AND QN.centrocostoid = CDV.centrocosto
         AND QN.divisionid = CDV.divisionid
         AND QN.quintonivelid = CDV.quintonivelid';
    END IF;
    
    -- Permisos dinámicos por nivel usando INNER JOIN
    RAISE NOTICE '=== APLICANDO PERMISOS DINAMICOS ===';
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;
    
    IF v_niveles = 1 THEN
        RAISE NOTICE 'Aplicando permisos nivel 1: accesoxusuariolugarespago';
        var_sql := var_sql || '
       INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.RutEmpresa
         AND ALP.lugarpagoid = CDV.LugarPagoid
         AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 2 THEN
        RAISE NOTICE 'Aplicando permisos nivel 2: accesoxusuariodepartamentos';
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 3 THEN
        RAISE NOTICE 'Aplicando permisos nivel 3: accesoxusuarioccosto';
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.RutEmpresa
         AND ACC.lugarpagoid = CDV.LugarPagoid
         AND ACC.departamentoid = CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 4 THEN
        RAISE NOTICE 'Aplicando permisos nivel 4: accesoxusuariodivision';
        var_sql := var_sql || '
       INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.RutEmpresa
         AND ADIV.lugarpagoid = CDV.LugarPagoid
         AND ADIV.departamentoid = CDV.departamentoid
         AND ADIV.centrocostoid = CDV.centrocosto
         AND ADIV.divisionid = CDV.divisionid
         AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
    ELSIF v_niveles = 5 THEN
        RAISE NOTICE 'Aplicando permisos nivel 5: accesoxusuarioquintonivel';
        var_sql := var_sql || '
       INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.RutEmpresa
         AND AQN.lugarpagoid = CDV.LugarPagoid
         AND AQN.departamentoid = CDV.departamentoid
         AND AQN.centrocostoid = CDV.centrocosto
         AND AQN.divisionid = CDV.divisionid
         AND AQN.quintonivelid = CDV.quintonivelid
         AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
    END IF;
    
    var_sql := var_sql || '
    ';

    -- Join a personas si filtrar por nombre
   IF p_pNombreEmpleado IS NOT NULL AND p_pNombreEmpleado <> '' THEN
    var_sql := var_sql || 
      ' AND ((PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''')))'
      || ' ILIKE ' || quote_literal('%' || p_pNombreEmpleado || '%');
END IF;
    -- Rol público
    IF v_rolid = 2 THEN
      var_sql := var_sql ||
      ' INNER JOIN empleados Emp ON CDV.Rut = Emp.empleadoid
        AND Emp.rolid = ' || v_rolid;
    END IF;

    -- Filtros base
    var_sql := var_sql ||
    ' WHERE C.Eliminado = false
      AND C.idEstado = ' || p_pidEstadoContrato;

    -- Filtros opcionales
    IF p_pidDocumento <> 0 THEN
        var_sql := var_sql || ' AND C.idDocumento = ' || p_pidDocumento;
    END IF;
    IF p_pidtipodocumento <> 0 THEN
        var_sql := var_sql || ' AND PL.idTipoDoc = ' || p_pidtipodocumento;
    END IF;
    IF p_pidTipoFirma <> 0 THEN
        var_sql := var_sql || ' AND C.idTipoFirma = ' || p_pidTipoFirma;
    END IF;
  
   IF p_pidProceso <> 0 THEN
       var_sql := var_sql || ' AND C.idproceso = ' || p_pidProceso;
    END IF;
    IF p_pRutEmpresa IS NOT NULL AND p_pRutEmpresa <> '' AND p_pRutEmpresa <> '0' THEN
        var_sql := var_sql || ' AND C.RutEmpresa = ' || quote_literal(p_pRutEmpresa);
    END IF;
    IF p_pRutEmpleado IS NOT NULL AND p_pRutEmpleado <> '' THEN
        var_sql := var_sql || ' AND CDV.Rut ILIKE ' || quote_literal('%' || p_pRutEmpleado || '%');
    END IF;
    -- Filtros dinámicos por nivel
    RAISE NOTICE '=== APLICANDO FILTROS DINAMICOS ===';
    
    IF v_niveles >= 1 AND p_plugarpagoid IS NOT NULL AND p_plugarpagoid <> '' THEN
        RAISE NOTICE 'Aplicando filtro lugar de pago: %', p_plugarpagoid;
        var_sql := var_sql || ' AND CDV.LugarPagoid = ' || quote_literal(p_plugarpagoid);
    END IF;

    IF v_niveles >= 1 AND p_pnombreLugarPago IS NOT NULL AND p_pnombreLugarPago <> '' THEN
        RAISE NOTICE 'Aplicando filtro nombre lugar de pago: %', p_pnombreLugarPago;
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%'||p_pnombreLugarPago||'%');
    END IF;

    IF v_niveles >= 2 AND p_pdepartamentoid IS NOT NULL AND p_pdepartamentoid <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro departamento: %', p_pdepartamentoid;
        END IF;
        var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_pdepartamentoid);
    END IF;

    IF v_niveles >= 2 AND p_pnombredepartamento IS NOT NULL AND p_pnombredepartamento <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro nombre departamento: %', p_pnombredepartamento;
        END IF;
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%'||p_pnombredepartamento||'%');
    END IF;

    IF v_niveles >= 3 AND p_pcentrocosto IS NOT NULL AND p_pcentrocosto <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro centro de costo: %', p_pcentrocosto;
        END IF;
        var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_pcentrocosto);
    END IF;

    IF v_niveles >= 3 AND p_pnombrecentrocosto IS NOT NULL AND p_pnombrecentrocosto <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro nombre centro de costo: %', p_pnombrecentrocosto;
        END IF;
        var_sql := var_sql || ' AND CCO.nombrecentrocosto ILIKE ' || quote_literal('%'||p_pnombrecentrocosto||'%');
    END IF;

    IF v_niveles >= 4 AND p_pdivisionid IS NOT NULL AND p_pdivisionid <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro división: %', p_pdivisionid;
        END IF;
        var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_pdivisionid);
    END IF;

    IF v_niveles >= 4 AND p_pnombredivision IS NOT NULL AND p_pnombredivision <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro nombre división: %', p_pnombredivision;
        END IF;
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%'||p_pnombredivision||'%');
    END IF;

    IF v_niveles = 5 AND p_pquintonivelid IS NOT NULL AND p_pquintonivelid <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro quinto nivel: %', p_pquintonivelid;
        END IF;
        var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_pquintonivelid);
    END IF;

    IF v_niveles = 5 AND p_pnombrequintonivel IS NOT NULL AND p_pnombrequintonivel <> '' THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Aplicando filtro nombre quinto nivel: %', p_pnombrequintonivel;
        END IF;
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%'||p_pnombrequintonivel||'%');
    END IF;

    -- Cierre CTE y paginación
    var_sql := var_sql ||
    ')
    SELECT
      C.idDocumento           AS "idDocumento",
      TD.NombreTipoDoc        AS "NombreTipoDoc",
      P.Descripcion           AS "Proceso",
      CE.Descripcion          AS "Estado",
      C.idEstado              AS "idEstado",
      FT.Descripcion          AS "Firma",
      TO_CHAR(C.FechaCreacion, ''DD-MM-YYYY'')   AS "FechaCreacion",
      TO_CHAR(C.FechaUltimaFirma, ''DD-MM-YYYY'') AS "FechaUltimaFirma",
      1                       AS "Semaforo",
	  WEP.DiasMax             AS "DiasMax",
	  C.idWF                  AS "idWF",
      C.RutEmpresa            AS "RutEmpresa",
      E.RazonSocial           AS "RazonSocial",
      C.Rut                   AS "Rut",
      PER.nombre              AS "nombre",
      PER.appaterno           AS "appaterno",
      PER.apmaterno           AS "apmaterno",
      CF.RutFirmante          AS "RutRep",
      REP.nombre              AS "nombre_rep",
      REP.appaterno           AS "appaterno_rep",
      REP.apmaterno           AS "apmaterno_rep"';
    
    -- Agregar campos de niveles dinámicamente al SELECT final
    IF p_debug = 0 THEN
        RAISE NOTICE '=== AGREGANDO CAMPOS DINAMICOS AL SELECT ===';
    END IF;
    
    IF v_niveles >= 1 THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Agregando campos nivel 1: LugarPagoid, nombrelugarpago';
        END IF;
        var_sql := var_sql || ',
      C.LugarPagoid           AS "LugarPagoid",
      C.nombrelugarpago       AS "nombrelugarpago"';
    END IF;
    IF v_niveles >= 2 THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Agregando campos nivel 2: departamentoid, nombredepartamento';
        END IF;
        var_sql := var_sql || ',
      C.departamentoid        AS "departamentoid",
      C.nombredepartamento    AS "nombredepartamento"';
    END IF;
    IF v_niveles >= 3 THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Agregando campos nivel 3: centrocostoid, nombrecentrocosto';
        END IF;
        var_sql := var_sql || ',
      C.centrocosto         AS "CentroCosto",
      C.nombrecentrocosto     AS "nombrecentrocosto"';
    END IF;
    IF v_niveles >= 4 THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Agregando campos nivel 4: divisionid, nombredivision';
        END IF;
        var_sql := var_sql || ',
      C.divisionid            AS "divisionid",
      C.nombredivision        AS "nombredivision"';
    END IF;
    IF v_niveles = 5 THEN
        IF p_debug = 0 THEN
            RAISE NOTICE 'Agregando campos nivel 5: quintonivelid, nombrequintonivel';
        END IF;
        var_sql := var_sql || ',
      C.quintonivelid         AS "quintonivelid",
      C.nombrequintonivel     AS "quintonivel"';
    END IF;
    
    var_sql := var_sql || '
    FROM DocumentosTabla C
    INNER JOIN TipoDocumentos TD ON TD.idTipoDoc = C.idTipoDoc
    INNER JOIN Procesos P         ON P.idProceso = C.idproceso
    INNER JOIN ContratosEstados CE ON CE.idEstado = C.idestado
    LEFT JOIN ContratoFirmantes CF ON C.idDocumento = CF.idDocumento
      AND C.idestado = CF.idEstado
    INNER JOIN FirmasTipos FT      ON FT.idTipoFirma = C.idtipofirma
    INNER JOIN Empresas E         ON E.RutEmpresa = C.RutEmpresa
    LEFT JOIN WorkflowEstadoProcesos WEP
      ON C.idwf = WEP.idWorkflow
     AND C.idestado = WEP.idEstadoWF
    INNER JOIN Personas PER       ON PER.personaid = C.rut
    LEFT JOIN Personas REP        ON REP.personaid = CF.RutFirmante
    WHERE C.linea BETWEEN ' || v_inicio || ' AND ' || v_fin || '
    ORDER BY C.linea';

    -- Debug: mostrar SQL generado
    RAISE NOTICE '=== SQL FINAL GENERADO ===';
    RAISE NOTICE '%', var_sql;
    RAISE NOTICE '=== FIN DEBUG SP_DOCUMENTOSPORAPROBAR_LISTADO ===';

    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR
      SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_documentosporaprobar_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, smallint)

-- DROP FUNCTION IF EXISTS public.sp_documentosporaprobar_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, smallint);

CREATE OR REPLACE FUNCTION public.sp_documentosporaprobar_total(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer DEFAULT 0,
	p_prutempresa character varying DEFAULT '',
	p_prutempleado character varying DEFAULT '',
	p_pnombreempleado character varying DEFAULT '',
	p_plugarpagoid character varying DEFAULT '',
	p_pnombrelugarpago character varying DEFAULT '',
	p_pdepartamentoid character varying DEFAULT '',
	p_pnombredepartamento character varying DEFAULT '',
	p_pcentrocosto character varying DEFAULT '',
	p_pnombrecentrocosto character varying DEFAULT '',
	p_pdivisionid character varying DEFAULT '',
	p_pnombredivision character varying DEFAULT '',
	p_pquintonivelid character varying DEFAULT '',
	p_pnombrequintonivel character varying DEFAULT '',
	p_pusuarioid character varying DEFAULT '',
	p_pfichaid integer DEFAULT 0,
	p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  var_sql     text;
  v_niveles   integer;
  v_totalorig bigint;
  v_total     integer;
  v_totalreg  numeric;
  v_rolid     integer;
  v_por_pagina integer;
BEGIN
  -- Obtener niveles dinámicamente
  SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
  
  -- Obtener rol del usuario
  SELECT rolid INTO v_rolid FROM usuarios WHERE usuarioid = p_pusuarioid;

  -- Construir consulta base (igual a la original)
  var_sql :=
  'WITH DocumentosTabla AS (
       SELECT C.idDocumento,
              CASE WHEN C.Eliminado THEN 1 ELSE 0 END AS EliminadoBool,
              CASE WHEN C.Enviado THEN 1 ELSE 0 END AS EnviadoBool,
              ROW_NUMBER() OVER (ORDER BY C.idDocumento DESC) AS linea
         FROM contratos C
         INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
         INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc AND T.tipousuarioid = ' || quote_literal(p_ptipousuarioid) || '
         INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento';

  -- JOINs dinámicos por nivel (solo agregar los que están disponibles)
  IF v_niveles >= 1 THEN
      var_sql := var_sql || '
         LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.LugarPagoid AND LP.empresaid = C.RutEmpresa';
  END IF;

  IF v_niveles >= 2 THEN
      var_sql := var_sql || '
         LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.empresaid = C.RutEmpresa AND DEP.lugarpagoid = CDV.LugarPagoid';
  END IF;

  IF v_niveles >= 3 THEN
      var_sql := var_sql || '
         LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.empresaid = C.RutEmpresa AND CCO.lugarpagoid = CDV.LugarPagoid AND CCO.departamentoid = CDV.departamentoid';
  END IF;

  IF v_niveles >= 4 THEN
      var_sql := var_sql || '
         LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.empresaid = C.RutEmpresa AND DIV.lugarpagoid = CDV.LugarPagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto';
  END IF;

  IF v_niveles = 5 THEN
      var_sql := var_sql || '
         LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.empresaid = C.RutEmpresa AND QN.lugarpagoid = CDV.LugarPagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid';
  END IF;

  -- Permisos dinámicos por nivel (reemplazar el JOIN fijo)
  IF v_niveles = 1 THEN
      var_sql := var_sql || '
         INNER JOIN accesoxusuariolugarespago ACC ON
             ACC.empresaid      = C.RutEmpresa
         AND ACC.lugarpagoid   = CDV.LugarPagoid
         AND ACC.usuarioid     = ' || quote_literal(p_pusuarioid) || '';
  ELSIF v_niveles = 2 THEN
      var_sql := var_sql || '
         INNER JOIN accesoxusuariodepartamentos ACC ON
             ACC.empresaid      = C.RutEmpresa
         AND ACC.lugarpagoid   = CDV.LugarPagoid
         AND ACC.departamentoid= CDV.departamentoid
         AND ACC.usuarioid     = ' || quote_literal(p_pusuarioid) || '';
  ELSIF v_niveles = 3 THEN
      var_sql := var_sql || '
         INNER JOIN accesoxusuarioccosto ACC ON
             ACC.empresaid      = C.RutEmpresa
         AND ACC.lugarpagoid   = CDV.LugarPagoid
         AND ACC.departamentoid= CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.usuarioid     = ' || quote_literal(p_pusuarioid) || '';
  ELSIF v_niveles = 4 THEN
      var_sql := var_sql || '
         INNER JOIN accesoxusuariodivision ACC ON
             ACC.empresaid      = C.RutEmpresa
         AND ACC.lugarpagoid   = CDV.LugarPagoid
         AND ACC.departamentoid= CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.divisionid    = CDV.divisionid
         AND ACC.usuarioid     = ' || quote_literal(p_pusuarioid) || '';
  ELSIF v_niveles = 5 THEN
      var_sql := var_sql || '
         INNER JOIN accesoxusuarioquintonivel ACC ON
             ACC.empresaid      = C.RutEmpresa
         AND ACC.lugarpagoid   = CDV.LugarPagoid
         AND ACC.departamentoid= CDV.departamentoid
         AND ACC.centrocostoid = CDV.centrocosto
         AND ACC.divisionid    = CDV.divisionid
         AND ACC.quintonivelid = CDV.quintonivelid
         AND ACC.usuarioid     = ' || quote_literal(p_pusuarioid) || '';
  END IF;

  -- Join a personas si filtrar por nombre (mismo que el SP de listado)
  IF p_pnombreempleado IS NOT NULL AND p_pnombreempleado <> '' THEN
      var_sql := var_sql || '
         INNER JOIN Personas PER ON PER.personaid = CDV.Rut';
  END IF;

  -- Rol público (mismo que el SP de listado)
  IF v_rolid = 2 THEN
      var_sql := var_sql || '
         INNER JOIN empleados Emp ON CDV.Rut = Emp.empleadoid
           AND Emp.rolid = ' || v_rolid;
  END IF;

  -- Filtros base
  var_sql := var_sql || '
      WHERE C.Eliminado = false
        AND C.idEstado = ' || p_pidestadocontrato;

  -- Filtros opcionales (mismos que el SP de listado)
  IF p_piddocumento <> 0 THEN
      var_sql := var_sql || ' AND C.idDocumento = ' || p_piddocumento;
  END IF;
  IF p_pidtipodocumento <> 0 THEN
      var_sql := var_sql || ' AND PL.idTipoDoc = ' || p_pidtipodocumento;
  END IF;
  IF p_pidtipofirma <> 0 THEN
      var_sql := var_sql || ' AND C.idTipoFirma = ' || p_pidtipofirma;
  END IF;

  IF p_pidproceso <> 0 THEN
      var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso;
  END IF;
  IF p_prutempresa IS NOT NULL AND p_prutempresa <> '' AND p_prutempresa <> '0' THEN
      var_sql := var_sql || ' AND C.RutEmpresa = ' || quote_literal(p_prutempresa);
  END IF;
  IF p_prutempleado IS NOT NULL AND p_prutempleado <> '' THEN
      var_sql := var_sql || ' AND CDV.Rut ILIKE ' || quote_literal('%' || p_prutempleado || '%');
  END IF;
  IF p_pnombreempleado IS NOT NULL AND p_pnombreempleado <> '' THEN
      var_sql := var_sql || ' AND ((PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, ''''))) ILIKE ' || quote_literal('%' || p_pnombreempleado || '%');
  END IF;

  -- Filtros dinámicos por nivel (mismos que el SP de listado)
  IF v_niveles >= 1 AND p_plugarpagoid IS NOT NULL AND p_plugarpagoid <> '' THEN
      var_sql := var_sql || ' AND CDV.LugarPagoid = ' || quote_literal(p_plugarpagoid);
  END IF;

  IF v_niveles >= 1 AND p_pnombrelugarpago IS NOT NULL AND p_pnombrelugarpago <> '' THEN
      var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%'||p_pnombrelugarpago||'%');
  END IF;

  IF v_niveles >= 2 AND p_pdepartamentoid IS NOT NULL AND p_pdepartamentoid <> '' THEN
      var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_pdepartamentoid);
  END IF;

  IF v_niveles >= 2 AND p_pnombredepartamento IS NOT NULL AND p_pnombredepartamento <> '' THEN
      var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%'||p_pnombredepartamento||'%');
  END IF;

  IF v_niveles >= 3 AND p_pcentrocosto IS NOT NULL AND p_pcentrocosto <> '' THEN
      var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_pcentrocosto);
  END IF;

  IF v_niveles >= 3 AND p_pnombrecentrocosto IS NOT NULL AND p_pnombrecentrocosto <> '' THEN
      var_sql := var_sql || ' AND CCO.nombrecentrocosto ILIKE ' || quote_literal('%'||p_pnombrecentrocosto||'%');
  END IF;

  IF v_niveles >= 4 AND p_pdivisionid IS NOT NULL AND p_pdivisionid <> '' THEN
      var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_pdivisionid);
  END IF;

  IF v_niveles >= 4 AND p_pnombredivision IS NOT NULL AND p_pnombredivision <> '' THEN
      var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%'||p_pnombredivision||'%');
  END IF;

  IF v_niveles = 5 AND p_pquintonivelid IS NOT NULL AND p_pquintonivelid <> '' THEN
      var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_pquintonivelid);
  END IF;

  IF v_niveles = 5 AND p_pnombrequintonivel IS NOT NULL AND p_pnombrequintonivel <> '' THEN
      var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%'||p_pnombrequintonivel||'%');
  END IF;

  var_sql := var_sql || '
  ) SELECT COUNT(*) FROM DocumentosTabla';

  IF p_debug = 0 THEN
    RAISE NOTICE '%', var_sql;
  END IF;

  EXECUTE var_sql INTO v_totalorig;

  -- cálculo correcto de páginas
  v_por_pagina := GREATEST(NULLIF(p_decuantos::int, 0), 1);
  v_total      := ((v_totalorig + v_por_pagina - 1) / v_por_pagina);  -- ceil entero
  v_totalreg   := v_totalorig;                                        -- total real

  OPEN p_refcursor FOR
    SELECT v_total AS total, v_totalreg AS totalreg;

  RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
  OPEN p_refcursor FOR SELECT 1 AS error, SQLERRM AS mensaje;
  RETURN p_refcursor;
END;
$BODY$;-- FUNCTION: public.sp_documentosporeliminar_listado(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosporeliminar_listado(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosporeliminar_listado(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer,
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_pusuarioid character varying,
	p_pfichaid integer,
	p_fechainicio date,
	p_fechafin date,
	p_rutempresa character varying,
	p_lugarpagoid character varying,
	p_nombrelugarpago character varying,
	p_departamentoid character varying,
	p_nombredepartamento character varying,
	p_centrocosto character varying,
	p_nombrecentrocosto character varying,
	p_divisionid character varying,
	p_nombredivision character varying,
	p_quintonivelid character varying DEFAULT '',
	p_nombrequintonivel character varying DEFAULT '',
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_Pinicio integer := (p_pagina - 1) * p_decuantos + 1;
    var_Pfin integer := p_pagina * p_decuantos;
    var_sql text;
    v_niveles integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentosporeliminar_listado - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Campos base (siempre presentes)
    var_sql := '
        SELECT * FROM (
            SELECT 
                C.idDocumento AS "idDocumento",
                TD.NombreTipoDoc AS "NombreTipoDoc",
                P.Descripcion AS "Proceso",
                CE.Descripcion AS "Estado",
                CE.idEstado AS "idEstado",
                FT.Descripcion AS "Firma",
                TO_CHAR(C.FechaCreacion, ''DD-MM-YYYY'') AS "FechaCreacion",
                TO_CHAR(C.FechaUltimaFirma, ''DD-MM-YYYY'') AS "FechaUltimaFirma",
                true AS "Semaforo",
                WEP.DiasMax AS "DiasEstadoActual",
                C.idWF AS "idWF",
                ROW_NUMBER() OVER (ORDER BY C.idDocumento DESC) AS "RowNum",
                C.RutEmpresa AS "RutEmpresa",
                E.RazonSocial AS "RazonSocial",
                CDV.Rut AS "Rut",
                PER.nombre AS "nombre",
                PER.appaterno AS "appaterno",
                PER.apmaterno AS "apmaterno",
                CF.RutFirmante AS "RutRep",
                REP.nombre AS "nombre_rep",
                REP.appaterno AS "appaterno_rep",
                REP.apmaterno AS "apmaterno_rep",
                FD.fichaid AS "fichaid"';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
                CDV.LugarPagoid AS "LugarPagoid",
                LP.nombrelugarpago AS "nombrelugarpago"';
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
                CDV.departamentoid AS "departamentoid",
                DEP.nombredepartamento AS "nombredepartamento"';
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
                CDV.centrocosto AS "CentroCosto",
                CCO.nombrecentrocosto AS "nombreCentroCosto"';
        RAISE NOTICE 'Agregando campo nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
                CDV.divisionid AS "divisionid",
                DIV.nombredivision AS "nombredivision"';
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
                CDV.quintonivelid AS "quintonivelid",
                QN.nombrequintonivel AS "nombrequintonivel"';
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
            FROM Contratos C
            INNER JOIN ContratoDatosVariables CDV ON CDV.idDocumento = C.idDocumento
            INNER JOIN Personas PER ON PER.personaid = CDV.Rut
            INNER JOIN Empresas E ON E.RutEmpresa = C.RutEmpresa
            LEFT JOIN ContratoFirmantes CF ON CF.idDocumento = C.idDocumento AND C.idEstado = CF.idEstado
            LEFT JOIN Personas REP ON REP.personaid = CF.RutFirmante
            LEFT JOIN fichasdocumentos FD ON C.idDocumento = FD.documentoid
            INNER JOIN Plantillas PL ON PL.idPlantilla = C.idPlantilla
            INNER JOIN TipoDocumentos TD ON TD.idTipoDoc = PL.idTipoDoc
            INNER JOIN Procesos P ON P.idProceso = C.idProceso
            INNER JOIN ContratosEstados CE ON CE.idEstado = C.idEstado
            INNER JOIN FirmasTipos FT ON FT.idTipoFirma = C.idTipoFirma
            LEFT JOIN WorkflowEstadoProcesos WEP ON C.idWF = WEP.idWorkflow AND C.idEstado = WEP.idEstadoWF
            INNER JOIN tiposdocumentosxperfil T ON PL.idPlantilla = T.idtipodoc AND T.tipousuarioid = ' || p_ptipousuarioid;

    -- JOINs de niveles dinámicos
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
            LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.LugarPagoid AND LP.empresaid = C.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
            LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.empresaid = C.RutEmpresa AND DEP.lugarpagoid = CDV.LugarPagoid';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
            LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.departamentoid = CDV.departamentoid AND CCO.lugarpagoid = CDV.LugarPagoid AND CCO.empresaid = C.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
            LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.centrocostoid = CDV.centrocosto AND DIV.departamentoid = CDV.departamentoid AND DIV.lugarpagoid = CDV.LugarPagoid AND DIV.empresaid = C.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
            LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.divisionid = CDV.divisionid AND QN.centrocostoid = CDV.centrocosto AND QN.departamentoid = CDV.departamentoid AND QN.lugarpagoid = CDV.LugarPagoid AND QN.empresaid = C.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.RutEmpresa AND ALP.lugarpagoid = CDV.LugarPagoid AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.RutEmpresa AND ACC.lugarpagoid = CDV.LugarPagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.RutEmpresa AND ACC.lugarpagoid = CDV.LugarPagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.RutEmpresa AND ADIV.lugarpagoid = CDV.LugarPagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.RutEmpresa AND AQN.lugarpagoid = CDV.LugarPagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Condiciones WHERE base
    var_sql := var_sql || '
            WHERE C.Eliminado = false';

    IF p_pFirmante <> '' THEN
        var_sql := var_sql || ' AND (PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''')) ILIKE ' || quote_literal('%' || p_pFirmante || '%');
    END IF;
    IF p_pRutFirmante <> '' THEN
        var_sql := var_sql || ' AND CDV.Rut ILIKE ' || quote_literal('%' || p_pRutFirmante || '%');
    END IF;
    IF p_pidDocumento <> 0 THEN
        var_sql := var_sql || ' AND C.idDocumento = ' || p_pidDocumento;
    END IF;
    IF p_pidtipodocumento <> 0 THEN
        var_sql := var_sql || ' AND PL.idTipoDoc = ' || p_pidtipodocumento;
    END IF;
    IF p_pidEstadoContrato > 0 THEN
        var_sql := var_sql || ' AND C.idEstado = ' || p_pidEstadoContrato;
    ELSIF p_pidEstadoContrato = 0 THEN
        var_sql := var_sql || ' AND C.idEstado <> 6';
    END IF;
    IF p_pidTipoFirma <> 0 THEN
        var_sql := var_sql || ' AND C.idTipoFirma = ' || p_pidTipoFirma;
    END IF;
    IF p_pidProceso <> 0 THEN
        var_sql := var_sql || ' AND P.idProceso = ' || p_pidProceso;
    END IF;
    IF p_pfichaid > 0 THEN
        var_sql := var_sql || ' AND FD.fichaid = ' || p_pfichaid;
    END IF;
    IF p_fechaInicio IS NOT NULL AND p_fechaFin IS NULL THEN
        var_sql := var_sql || ' AND C.FechaCreacion BETWEEN ''' || p_fechaInicio || ''' AND ''' || (p_fechaInicio + INTERVAL '1 day' - INTERVAL '0.01 seconds') || '''';
    ELSIF p_fechaInicio IS NOT NULL AND p_fechaFin IS NOT NULL THEN
        var_sql := var_sql || ' AND C.FechaCreacion BETWEEN ''' || p_fechaInicio || ''' AND ''' || (p_fechaFin + INTERVAL '1 day' - INTERVAL '0.01 seconds') || '''';
    ELSIF p_fechaInicio IS NULL AND p_fechaFin IS NOT NULL THEN
        var_sql := var_sql || ' AND C.FechaCreacion <= ''' || (p_fechaFin + INTERVAL '1 day' - INTERVAL '0.01 seconds') || '''';
    END IF;
    IF p_RutEmpresa <> '' THEN
        var_sql := var_sql || ' AND C.RutEmpresa = ' || quote_literal(p_RutEmpresa);
    END IF;

    -- Filtros dinámicos para nivel 1 (lugarespago)
    IF v_niveles >= 1 AND p_lugarpagoid <> '' THEN
        var_sql := var_sql || ' AND CDV.LugarPagoid = ' || quote_literal(p_lugarpagoid);
    END IF;

    IF v_niveles >= 1 AND p_nombreLugarPago <> '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%' || p_nombreLugarPago || '%');
    END IF;

    -- Filtros dinámicos para nivel 2 (departamentos)
    IF v_niveles >= 2 AND p_departamentoid <> '' THEN
        var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_departamentoid);
    END IF;

    IF v_niveles >= 2 AND p_nombredepartamento <> '' THEN
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%' || p_nombredepartamento || '%');
    END IF;

    -- Filtros dinámicos para nivel 3 (centroscosto)
    IF v_niveles >= 3 AND p_centrocosto <> '' THEN
        var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_centrocosto);
    END IF;

    IF v_niveles >= 3 AND p_nombrecentrocosto <> '' THEN
        var_sql := var_sql || ' AND CCO.nombrecentrocosto ILIKE ' || quote_literal('%' || p_nombrecentrocosto || '%');
    END IF;

    -- Filtros dinámicos para nivel 4 (division)
    IF v_niveles >= 4 AND p_divisionid <> '' THEN
        var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_divisionid);
    END IF;

    IF v_niveles >= 4 AND p_nombredivision <> '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%' || p_nombredivision || '%');
    END IF;

    -- Filtros dinámicos para nivel 5 (quintonivel)
    IF v_niveles = 5 AND p_quintonivelid <> '' THEN
        var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid);
    END IF;

    IF v_niveles = 5 AND p_nombrequintonivel <> '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%' || p_nombrequintonivel || '%');
    END IF;

    var_sql := var_sql || ') sub WHERE "RowNum" BETWEEN ' || var_Pinicio || ' AND ' || var_Pfin || ';';

    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida (primeros 500 caracteres): %', LEFT(var_sql, 500);

    IF p_debug = 1 THEN
        RAISE NOTICE 'SQL COMPLETO: %', var_sql;
    END IF;

    RAISE NOTICE 'Ejecutando consulta de listado con paginación';

    OPEN p_refcursor FOR EXECUTE var_sql;
    
    RAISE NOTICE 'FIN sp_documentosporeliminar_listado - Consulta ejecutada exitosamente';
    
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR en sp_documentosporeliminar_listado: %', SQLERRM;
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;
-- FUNCTION: public.sp_documentosporeliminar_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosporeliminar_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, integer, date, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosporeliminar_total(
	p_cursor refcursor,
	p_tipo_usuario_id integer,
	p_pagina integer,
	p_de_cuantos numeric,
	p_id_documento integer,
	p_id_tipo_documento integer,
	p_id_estado_contrato integer,
	p_id_tipo_firma integer,
	p_id_proceso integer,
	p_firmante character varying,
	p_rut_firmante character varying,
	p_usuario_id character varying,
	p_ficha_id integer,
	p_fecha_inicio date,
	p_fecha_fin date,
	p_rut_empresa character varying,
	p_lugar_pago_id character varying,
	p_nombre_lugar_pago character varying,
	p_departamento_id character varying,
	p_nombre_departamento character varying,
	p_centro_costo character varying,
	p_nombre_centro_costo character varying,
	p_division_id character varying,
	p_nombre_division character varying,
	p_quintonivel_id character varying DEFAULT '',
	p_nombre_quintonivel character varying DEFAULT '',
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_total INTEGER;
    v_total_orig INTEGER;
    v_total_reg DECIMAL(9,2);
    
    v_p_inicio INTEGER;
    v_p_fin INTEGER;
    v_nl CHAR(2) := CHR(13) || CHR(10);
    v_firmante_like VARCHAR(100);
    v_rut_firmante_like VARCHAR(12);
    
    v_centro_costo_id_like VARCHAR(12);
    v_centro_costo_like VARCHAR(100);
    v_lugar_pago_id_like VARCHAR(12);
    v_lugar_pago_like VARCHAR(100);
    v_departamento_id_like VARCHAR(12);
    v_departamento_like VARCHAR(100);
    v_division_id_like VARCHAR(12);
    v_division_like VARCHAR(100);
    v_quintonivel_id_like VARCHAR(12);
    v_quintonivel_like VARCHAR(100);
    
    v_sql_string TEXT;
    v_decimal DECIMAL(9,2);
    v_rol_id INTEGER;
    v_mensaje VARCHAR(100);
    v_niveles INTEGER;
    
    v_x_fecha_inicio TIMESTAMP;
    v_x_fecha_fin TIMESTAMP;
    
    -- ❌ ELIMINADO: v_temp_table_name TEXT;
BEGIN
    -- Log de inicio
    RAISE NOTICE 'INICIO sp_documentosporeliminar_total - Usuario: %', COALESCE(p_usuario_id, 'NULL');

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    v_p_inicio := (p_pagina - 1) * p_de_cuantos + 1;
    v_p_fin := p_pagina * p_de_cuantos;
    
    v_firmante_like := '%' || COALESCE(p_firmante, '') || '%';
    v_rut_firmante_like := '%' || COALESCE(p_rut_firmante, '') || '%';
    
    v_lugar_pago_id_like := '%' || COALESCE(p_lugar_pago_id, '') || '%';
    v_lugar_pago_like := '%' || COALESCE(p_nombre_lugar_pago, '') || '%';
    
    v_departamento_id_like := '%' || COALESCE(p_departamento_id, '') || '%';
    v_departamento_like := '%' || COALESCE(p_nombre_departamento, '') || '%';
    
    v_centro_costo_id_like := '%' || COALESCE(p_centro_costo, '') || '%';
    v_centro_costo_like := '%' || COALESCE(p_nombre_centro_costo, '') || '%';
    
    v_division_id_like := '%' || COALESCE(p_division_id, '') || '%';
    v_division_like := '%' || COALESCE(p_nombre_division, '') || '%';
    
    v_quintonivel_id_like := '%' || COALESCE(p_quintonivel_id, '') || '%';
    v_quintonivel_like := '%' || COALESCE(p_nombre_quintonivel, '') || '%';
    
    -- Procesar fechas
    IF p_fecha_inicio IS NOT NULL THEN
        v_x_fecha_inicio := p_fecha_inicio::timestamp;
    END IF;
    
    IF p_fecha_fin IS NOT NULL THEN
        v_x_fecha_fin := p_fecha_fin::timestamp + INTERVAL '23:59:59.99';
    END IF;
    
    -- Buscar el rol del usuario
    SELECT rolid INTO v_rol_id FROM usuarios WHERE usuarioid = p_usuario_id;
    
    IF v_rol_id IS NULL THEN
        v_mensaje := 'El usuario no tiene rol asignado';
    END IF;
    
    -- ✅ OPTIMIZACIÓN: Construir consulta directa con WITH (sin tabla temporal)
    v_sql_string := '
        WITH temp_tdocxperfil AS (
            SELECT C.iddocumento, 
                   (SELECT COUNT(*) FROM contratofirmantes WHERE iddocumento = C.iddocumento AND firmado = true) as cantfirmas
            FROM contratos C
            INNER JOIN contratodatosvariables CDV ON C.iddocumento = CDV.iddocumento
            INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla';
    
    -- Aplicar permisos dinámicos en temp_tdocxperfil
    RAISE NOTICE 'Aplicando permisos en temp_tdocxperfil para nivel: %', v_niveles;
    
    IF v_niveles = 1 THEN
        v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa AND ALP.lugarpagoid = CDV.lugarpagoid AND ALP.usuarioid = $1';
    ELSIF v_niveles = 2 THEN
        v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.usuarioid = $1';
    ELSIF v_niveles = 3 THEN
        v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa AND ACC.lugarpagoid = CDV.lugarpagoid AND ACC.departamentoid = CDV.departamentoid AND ACC.centrocostoid = CDV.centrocosto AND ACC.usuarioid = $1';
    ELSIF v_niveles = 4 THEN
        v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa AND ADIV.lugarpagoid = CDV.lugarpagoid AND ADIV.departamentoid = CDV.departamentoid AND ADIV.centrocostoid = CDV.centrocosto AND ADIV.divisionid = CDV.divisionid AND ADIV.usuarioid = $1';
    ELSIF v_niveles = 5 THEN
        v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa AND AQN.lugarpagoid = CDV.lugarpagoid AND AQN.departamentoid = CDV.departamentoid AND AQN.centrocostoid = CDV.centrocosto AND AQN.divisionid = CDV.divisionid AND AQN.quintonivelid = CDV.quintonivelid AND AQN.usuarioid = $1';
    END IF;
    
    v_sql_string := v_sql_string || '
            INNER JOIN tiposdocumentosxperfil TAPP ON TAPP.idtipodoc = PL.idplantilla AND TAPP.tipousuarioid = $2
            WHERE C.eliminado = false
        ),
        DocumentosTabla AS (
            SELECT 
                C.iddocumento
            FROM contratos C
            INNER JOIN temp_tdocxperfil TDPP ON C.iddocumento = TDPP.iddocumento AND TDPP.cantfirmas = 0
            INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla
            INNER JOIN tipodocumentos TD ON PL.idtipodoc = TD.idtipodoc
            INNER JOIN procesos P ON P.idproceso = C.idproceso
            INNER JOIN contratosestados CE ON CE.idestado = C.idestado
            INNER JOIN firmastipos FT ON FT.idtipofirma = C.idtipofirma
            INNER JOIN empresas E ON E.rutempresa = C.rutempresa
            LEFT JOIN workflowestadoprocesos WEP ON C.idwf = idworkflow AND C.idestado = WEP.idestadowf
            INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento
            INNER JOIN personas PER ON PER.personaid = CDV.rut
            LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND CF.rutempresa = C.rutempresa AND C.idestado = CF.idestado
            LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante';
    
    -- JOINs de niveles dinámicos
    IF v_niveles >= 1 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.empresaid = C.rutempresa AND DEP.lugarpagoid = CDV.lugarpagoid';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.departamentoid = CDV.departamentoid AND CCO.lugarpagoid = CDV.lugarpagoid AND CCO.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.centrocostoid = CDV.centrocosto AND DIV.departamentoid = CDV.departamentoid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.empresaid = C.rutempresa';
    END IF;
    
    IF v_niveles = 5 THEN
        v_sql_string := v_sql_string || '
            LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.divisionid = CDV.divisionid AND QN.centrocostoid = CDV.centrocosto AND QN.departamentoid = CDV.departamentoid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.empresaid = C.rutempresa';
    END IF;
    
    v_sql_string := v_sql_string || '
            LEFT JOIN fichasdocumentos FD ON C.iddocumento = FD.documentoid
            ';
    
    -- Validar el rol
    IF v_rol_id = 2 THEN -- 1: Privado y 2: Público
        v_sql_string := v_sql_string || ' INNER JOIN empleados Emp ON CDV.rut = Emp.empleadoid AND Emp.rolid = $3 ';
    END IF;
    
    v_sql_string := v_sql_string || ' WHERE 1=1';
    
    IF p_firmante != '' THEN
        v_sql_string := v_sql_string || ' AND ((PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''')) LIKE $4)';
    END IF;
    
    IF p_rut_firmante != '' THEN
        v_sql_string := v_sql_string || ' AND (PER.personaid LIKE $5)';
    END IF;
    
    IF p_id_documento != 0 THEN
        v_sql_string := v_sql_string || ' AND C.iddocumento = $6';
    END IF;
    
    IF p_id_tipo_documento != 0 THEN
        v_sql_string := v_sql_string || ' AND PL.idtipodoc = $7';
    END IF;
    
    IF p_id_estado_contrato > 0 THEN
        v_sql_string := v_sql_string || ' AND C.idestado = $8 AND C.idestado <> 6';
    END IF;
    
    IF p_id_estado_contrato = 0 THEN
        v_sql_string := v_sql_string || ' AND C.idestado <> 6';
    END IF;
    
    IF p_id_tipo_firma != 0 THEN
        v_sql_string := v_sql_string || ' AND C.idtipofirma = $9';
    END IF;
    
    IF p_id_proceso != 0 THEN
        v_sql_string := v_sql_string || ' AND P.idproceso = $10';
    END IF;
    
    -- Validar ficha
    IF p_ficha_id > 0 THEN
        v_sql_string := v_sql_string || ' AND FD.fichaid = $11';
    END IF;
    
    IF p_fecha_inicio IS NOT NULL AND p_fecha_fin IS NULL THEN
        v_x_fecha_fin := p_fecha_inicio::timestamp + INTERVAL '23:59:59.99';
        v_sql_string := v_sql_string || ' AND C.fechacreacion BETWEEN $12 AND $13';
    END IF;
    
    IF p_fecha_inicio IS NOT NULL AND p_fecha_fin IS NOT NULL THEN
        v_sql_string := v_sql_string || ' AND C.fechacreacion BETWEEN $12 AND $13';
    END IF;
    
    IF p_fecha_inicio IS NULL AND p_fecha_fin IS NOT NULL THEN
        v_sql_string := v_sql_string || ' AND C.fechacreacion <= $13';
    END IF;
    
    IF p_rut_empresa != '' THEN
        v_sql_string := v_sql_string || ' AND C.rutempresa = $14';
    END IF;
    
    -- Filtros dinámicos para nivel 1 (lugarespago)
    IF v_niveles >= 1 AND p_lugar_pago_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.lugarpagoid = $15';
    END IF;
    
    IF v_niveles >= 1 AND p_nombre_lugar_pago != '' THEN
        v_sql_string := v_sql_string || ' AND (LP.nombrelugarpago LIKE $16)';
    END IF;
    
    -- Filtros dinámicos para nivel 2 (departamentos)
    IF v_niveles >= 2 AND p_departamento_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.departamentoid = $17';
    END IF;
    
    IF v_niveles >= 2 AND p_nombre_departamento != '' THEN
        v_sql_string := v_sql_string || ' AND (DEP.nombredepartamento LIKE $18)';
    END IF;
    
    -- Filtros dinámicos para nivel 3 (centroscosto)
    IF v_niveles >= 3 AND p_centro_costo != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.centrocosto = $19';
    END IF;
    
    IF v_niveles >= 3 AND p_nombre_centro_costo != '' THEN
        v_sql_string := v_sql_string || ' AND (CCO.nombrecentrocosto LIKE $20)';
    END IF;
    
    -- Filtros dinámicos para nivel 4 (division)
    IF v_niveles >= 4 AND p_division_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.divisionid = $21';
    END IF;
    
    IF v_niveles >= 4 AND p_nombre_division != '' THEN
        v_sql_string := v_sql_string || ' AND (DIV.nombredivision LIKE $22)';
    END IF;
    
    -- Filtros dinámicos para nivel 5 (quintonivel)
    IF v_niveles = 5 AND p_quintonivel_id != '' THEN
        v_sql_string := v_sql_string || ' AND CDV.quintonivelid = $23';
    END IF;
    
    IF v_niveles = 5 AND p_nombre_quintonivel != '' THEN
        v_sql_string := v_sql_string || ' AND (QN.nombrequintonivel LIKE $24)';
    END IF;
    
    v_sql_string := v_sql_string || ' GROUP BY C.iddocumento
        )
        SELECT COUNT(iddocumento) FROM DocumentosTabla';
    
    IF p_debug = 1 THEN
        RAISE NOTICE 'SQL COMPLETO: %', v_sql_string;
    END IF;
    
    RAISE NOTICE 'Ejecutando consulta de conteo';
    
    -- Ejecutar la consulta dinámica
    EXECUTE v_sql_string 
    INTO v_total_orig
    USING p_usuario_id, p_tipo_usuario_id, v_rol_id, v_firmante_like, v_rut_firmante_like, 
          p_id_documento, p_id_tipo_documento, p_id_estado_contrato, p_id_tipo_firma, p_id_proceso,
          p_ficha_id, v_x_fecha_inicio, v_x_fecha_fin, p_rut_empresa, p_lugar_pago_id,
          v_lugar_pago_like, p_departamento_id, v_departamento_like, p_centro_costo, 
          v_centro_costo_like, p_division_id, v_division_like, p_quintonivel_id, v_quintonivel_like;
    
    v_total_reg := (v_total_orig / p_de_cuantos);
    v_decimal := v_total_reg - FLOOR(v_total_reg);
    
    IF v_decimal > 0 THEN
        v_total := FLOOR(v_total_reg) + 1;
    ELSE
        v_total := FLOOR(v_total_reg);
    END IF;
    
    v_total_reg := v_total_reg * p_de_cuantos;
    
    RAISE NOTICE 'Total de registros: % - Total de páginas: %', v_total_orig, v_total;
    
    -- Abrir el cursor con el resultado
    OPEN p_cursor FOR
    SELECT v_total AS total, v_total_reg AS totalreg;
    
    RAISE NOTICE 'FIN sp_documentosporeliminar_total - Consulta ejecutada exitosamente';
    
    -- Retornar el cursor
    RETURN p_cursor;

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR en sp_documentosporeliminar_total: %', SQLERRM;
    RAISE EXCEPTION 'Error en sp_documentosporeliminar_total: %', SQLERRM;
END;
$BODY$;

-- FUNCTION: public.sp_documentosvigentes_listado(refcursor, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_listado(refcursor, integer, integer, integer, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_listado(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos integer,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer,
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_plugarpagoid character varying,
	p_pnombrelugarpago character varying,
	p_pdepartamentoid character varying,
	p_pnombredepartamento character varying,
	p_pcentrocosto character varying,
	p_pnombrecentrocosto character varying,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
	p_pquintonivelid character varying,
	p_pnombrequintonivel character varying,
	p_pusuarioid character varying,
	p_pempresa character varying,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql text;
    v_niveles integer;
    v_rolid integer;
    v_inicio integer;
    v_fin integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentosvigentes_listado - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;
    RAISE NOTICE 'Rol del usuario: %', v_rolid;

    -- Calcular paginación
    v_inicio := (p_pagina - 1) * p_decuantos + 1;
    v_fin := p_pagina * p_decuantos;

    -- Construcción dinámica de campos SELECT
    var_sql := '
    WITH DocumentosTabla AS (
        SELECT
            c.iddocumento,
            p.idplantilla,
            p.idtipodoc,
            c.idproceso,
            c.idestado,
            c.idtipofirma,
            to_char(c.fechacreacion, ''DD/MM/YYYY'') AS fechacreacion,
            to_char(c.fechaultimafirma, ''DD/MM/YYYY'') AS fechaultimafirma,
            1 AS semaforo,
            c.idwf,
            ROW_NUMBER() OVER (ORDER BY c.iddocumento DESC) AS rownum,
            c.rutempresa,
            e.razonsocial,
            cdv.rut,
            per.nombre,
            per.appaterno,
            per.apmaterno,
            (per.nombre||'' ''||per.appaterno||'' ''||per.apmaterno) AS nombreempleado,
            rep.personaid AS rutrep,
            rep.nombre AS nombre_rep,
            rep.appaterno AS appaterno_rep,
            rep.apmaterno AS apmaterno_rep,
            (rep.nombre||'' ''||rep.appaterno||'' ''||rep.apmaterno) AS nombrerepresentante';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
            cdv.lugarpagoid,
            lp.nombrelugarpago';
        RAISE NOTICE 'Agregando campos nivel 1: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
            cdv.departamentoid,
            dep.nombredepartamento';
        RAISE NOTICE 'Agregando campos nivel 2: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
            cdv.centrocosto AS centrocostoid,
            cco.nombrecentrocosto';
        RAISE NOTICE 'Agregando campos nivel 3: centroscosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
            cdv.divisionid,
            div.nombredivision';
        RAISE NOTICE 'Agregando campos nivel 4: division';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
            cdv.quintonivelid,
            qn.nombrequintonivel';
        RAISE NOTICE 'Agregando campos nivel 5: quinto_nivel';
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
        FROM contratos c
        INNER JOIN plantillas p
            ON p.idplantilla = c.idplantilla
        INNER JOIN tiposdocumentosxperfil t
            ON p.idplantilla = t.idtipodoc
           AND t.tipousuarioid = ' || p_ptipousuarioid || '
        INNER JOIN empresas e
            ON e.rutempresa = c.rutempresa
        INNER JOIN contratodatosvariables cdv
            ON cdv.iddocumento = c.iddocumento
        INNER JOIN personas per
            ON per.personaid = cdv.rut
        LEFT JOIN contratofirmantes cf
            ON cf.iddocumento = c.iddocumento
           AND cf.idestado = 2
        LEFT JOIN personas rep
            ON rep.personaid = cf.rutfirmante';

    -- JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        LEFT JOIN lugarespago lp
            ON lp.lugarpagoid = cdv.lugarpagoid
           AND lp.empresaid = c.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        LEFT JOIN departamentos dep
            ON dep.lugarpagoid = cdv.lugarpagoid
           AND dep.departamentoid = cdv.departamentoid
           AND dep.empresaid = c.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        LEFT JOIN centroscosto cco
            ON cco.centrocostoid = cdv.centrocosto
           AND cco.lugarpagoid = cdv.lugarpagoid
           AND cco.departamentoid = cdv.departamentoid
           AND cco.empresaid = c.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        LEFT JOIN division div
            ON div.divisionid = cdv.divisionid
           AND div.lugarpagoid = cdv.lugarpagoid
           AND div.departamentoid = cdv.departamentoid
           AND div.centrocostoid = cdv.centrocosto
           AND div.empresaid = c.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel qn
            ON qn.quintonivelid = cdv.quintonivelid
           AND qn.lugarpagoid = cdv.lugarpagoid
           AND qn.departamentoid = cdv.departamentoid
           AND qn.centrocostoid = cdv.centrocosto
           AND qn.divisionid = cdv.divisionid
           AND qn.empresaid = c.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago alp
            ON alp.empresaid = c.rutempresa
           AND alp.lugarpagoid = cdv.lugarpagoid
           AND alp.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos acc
            ON acc.empresaid = c.rutempresa
           AND acc.lugarpagoid = cdv.lugarpagoid
           AND acc.departamentoid = cdv.departamentoid
           AND acc.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto acc
            ON acc.empresaid = c.rutempresa
           AND acc.lugarpagoid = cdv.lugarpagoid
           AND acc.departamentoid = cdv.departamentoid
           AND acc.centrocostoid = cdv.centrocosto
           AND acc.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision adiv
            ON adiv.empresaid = c.rutempresa
           AND adiv.lugarpagoid = cdv.lugarpagoid
           AND adiv.departamentoid = cdv.departamentoid
           AND adiv.centrocostoid = cdv.centrocosto
           AND adiv.divisionid = cdv.divisionid
           AND adiv.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel aqn
            ON aqn.empresaid = c.rutempresa
           AND aqn.lugarpagoid = cdv.lugarpagoid
           AND aqn.departamentoid = cdv.departamentoid
           AND aqn.centrocostoid = cdv.centrocosto
           AND aqn.divisionid = cdv.divisionid
           AND aqn.quintonivelid = cdv.quintonivelid
           AND aqn.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Aplicar filtro por ROL si es necesario (2 = Público)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
        INNER JOIN empleados emp
            ON cdv.rut = emp.empleadoid
           AND emp.rolid = ' || v_rolid;
        RAISE NOTICE 'Agregando filtro por ROL: %', v_rolid;
    END IF;

    -- Condiciones WHERE base
    var_sql := var_sql || '
        WHERE c.eliminado = false
          AND t.tipousuarioid = ' || p_ptipousuarioid;

    -- Filtros de firmante (primero, como en SQL Server)
    IF p_pfirmante != '' THEN
        var_sql := var_sql || ' AND (rep.nombre || '' '' || rep.appaterno || '' '' || rep.apmaterno) ILIKE ' || quote_literal('%' || p_pfirmante || '%');
    END IF;

    IF p_prutfirmante != '' THEN
        var_sql := var_sql || ' AND rep.personaid ILIKE ' || quote_literal('%' || p_prutfirmante || '%');
    END IF;

    -- Filtros de documento
    IF p_piddocumento != 0 THEN
        var_sql := var_sql || ' AND c.iddocumento = ' || p_piddocumento;
    END IF;

    IF p_pidtipodocumento != 0 THEN
        var_sql := var_sql || ' AND p.idtipodoc = ' || p_pidtipodocumento;
    END IF;

    -- Filtro de estado (con lógica especial como SQL Server)
    IF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || ' AND c.idestado = ' || p_pidestadocontrato;
    ELSIF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || ' AND c.idestado IN (1,2,3,6,8,9,10,11)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || ' AND c.idestado IN (2,3,10,11)';
    END IF;

    IF p_pidtipofirma != 0 THEN
        var_sql := var_sql || ' AND c.idtipofirma = ' || p_pidtipofirma;
    END IF;

    IF p_pidproceso != 0 THEN
        var_sql := var_sql || ' AND c.idproceso = ' || p_pidproceso;
    END IF;

    -- Filtros dinámicos por nivel (orden como SQL Server)
    IF v_niveles >= 1 AND p_plugarpagoid != '' THEN
        var_sql := var_sql || ' AND cdv.lugarpagoid = ' || quote_literal(p_plugarpagoid);
    END IF;

    IF v_niveles >= 1 AND p_pnombrelugarpago != '' THEN
        var_sql := var_sql || ' AND lp.nombrelugarpago ILIKE ' || quote_literal('%' || p_pnombrelugarpago || '%');
    END IF;

    IF v_niveles >= 2 AND p_pdepartamentoid != '' THEN
        var_sql := var_sql || ' AND cdv.departamentoid = ' || quote_literal(p_pdepartamentoid);
    END IF;

    IF v_niveles >= 2 AND p_pnombredepartamento != '' THEN
        var_sql := var_sql || ' AND dep.nombredepartamento ILIKE ' || quote_literal('%' || p_pnombredepartamento || '%');
    END IF;

    IF v_niveles >= 3 AND p_pcentrocosto != '' THEN
        var_sql := var_sql || ' AND cdv.centrocosto = ' || quote_literal(p_pcentrocosto);
    END IF;

    IF v_niveles >= 3 AND p_pnombrecentrocosto != '' THEN
        var_sql := var_sql || ' AND cco.nombrecentrocosto ILIKE ' || quote_literal('%' || p_pnombrecentrocosto || '%');
    END IF;

    IF v_niveles >= 4 AND p_pdivisionid != '' THEN
        var_sql := var_sql || ' AND cdv.divisionid = ' || quote_literal(p_pdivisionid);
    END IF;

    IF v_niveles >= 4 AND p_pnombredivision != '' THEN
        var_sql := var_sql || ' AND div.nombredivision ILIKE ' || quote_literal('%' || p_pnombredivision || '%');
    END IF;

    IF v_niveles = 5 AND p_pquintonivelid != '' THEN
        var_sql := var_sql || ' AND cdv.quintonivelid = ' || quote_literal(p_pquintonivelid);
    END IF;

    IF v_niveles = 5 AND p_pnombrequintonivel != '' THEN
        var_sql := var_sql || ' AND qn.nombrequintonivel ILIKE ' || quote_literal('%' || p_pnombrequintonivel || '%');
    END IF;

    -- Filtro de empresa (al final como SQL Server)
    IF p_pempresa != '' AND p_pempresa != '0' THEN
        var_sql := var_sql || ' AND c.rutempresa = ' || quote_literal(p_pempresa);
    END IF;

    -- Cerrar CTE
    var_sql := var_sql || '
    )
    SELECT
        dt.iddocumento AS "idDocumento",
        dt.idtipodoc AS "idTipoDoc",
        td.nombretipodoc AS "NombreTipoDoc",
        pr.descripcion AS "Proceso",
        ce.descripcion AS "Estado",
        dt.idestado AS "idEstado",
        ft.descripcion AS "Firma",
        dt.fechacreacion AS "FechaCreacion",
        dt.fechaultimafirma AS "FechaUltimaFirma",
        dt.semaforo AS "Semaforo",
        wep.diasmax AS "DiasEstadoActual",
        dt.idwf AS "idWF",
        dt.rownum AS "Rownum",
        dt.rutempresa AS "RutEmpresa",
        dt.razonsocial AS "RazonSocial",
        dt.rut AS "Rut",
        dt.nombre AS "nombre",
        dt.appaterno AS "appaterno",
        dt.apmaterno AS "apmaterno",
        dt.nombreempleado AS "NombreEmpleado",
        dt.rutrep AS "RutRep",
        dt.nombre_rep AS "nombre_rep",
        dt.appaterno_rep AS "appaterno_rep",
        dt.apmaterno_rep AS "apmaterno_rep",
        dt.nombrerepresentante AS "NombreRepresentante"';

    -- Agregar campos de niveles en el SELECT final
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
        dt.lugarpagoid AS "LugarPagoid",
        dt.nombrelugarpago AS "nombrelugarpago"';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
        dt.departamentoid AS "departamentoid",
        dt.nombredepartamento AS "nombredepartamento"';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
        dt.centrocostoid AS "CentroCosto",
        dt.nombrecentrocosto AS "nombreCentroCosto"';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
        dt.divisionid AS "divisionid",
        dt.nombredivision AS "nombredivision"';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
        dt.quintonivelid AS "quintonivelid",
        dt.nombrequintonivel AS "nombrequintonivel"';
    END IF;

    var_sql := var_sql || '
    FROM DocumentosTabla dt
    INNER JOIN tipodocumentos td
        ON dt.idtipodoc = td.idtipodoc
    INNER JOIN procesos pr
        ON dt.idproceso = pr.idproceso
    INNER JOIN contratosestados ce
        ON dt.idestado = ce.idestado
    INNER JOIN firmastipos ft
        ON dt.idtipofirma = ft.idtipofirma
    LEFT JOIN workflowestadoprocesos wep
        ON dt.idwf = wep.idworkflow
       AND dt.idestado = wep.idestadowf
    WHERE dt.rownum BETWEEN ' || v_inicio || ' AND ' || v_fin;

    -- Debug
    IF p_debug = 1 THEN
        RAISE NOTICE 'Consulta SQL final: %', var_sql;
    END IF;

    RAISE NOTICE 'Ejecutando consulta de listado con paginación';

    -- Abrir cursor con los resultados
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_documentosvigentes_listado: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_documentosvigentes_listado: %', SQLERRM;
END;
$BODY$;

-- FUNCTION: public.sp_documentosvigentes_listado_porprocesos_2(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_listado_porprocesos_2(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, smallint);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_listado_porprocesos_2(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_piddocumento integer,
	p_pidtipodocumento integer,
	p_pidestadocontrato integer,
	p_pidtipofirma integer,
	p_pidproceso integer,
	p_pfirmante character varying,
	p_prutfirmante character varying,
	p_plugarpagoid character varying,
	p_pnombrelugarpago character varying,
	p_pdepartamentoid character varying,
	p_pnombredepartamento character varying,
	p_pcentrocosto character varying,
	p_pnombrecentrocosto character varying,
	p_pdivisionid character varying,
	p_pnombredivision character varying,
	p_quintonivelid character varying,
	p_nombrequintonivel character varying,
	p_pusuarioid character varying,
	p_pempresa character varying,
    p_prutempresa_input character varying,
    p_prutempleado character varying,
    p_pempleado character varying,
    p_fechainicio date,
	p_fechafin date,
	p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  var_offset INTEGER := (p_pagina - 1) * p_decuantos;
    v_rolid INTEGER;
    v_niveles INTEGER;
    var_sql TEXT;
    var_log_message TEXT;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentosvigentes_listado_porprocesos_2 - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

  -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
   WHERE usuarioid = p_pusuarioid;

    -- ====== Construcción dinámica de SQL ======
    -- Campos base del SELECT (siempre presentes)
    var_sql := '
  WITH DocumentosTabla AS (
    SELECT
      C.iddocumento,
      PL.idplantilla,
      PL.idtipodoc,
      C.idproceso,
      C.idestado,
      C.idtipofirma,
      FD.fichaid,
        to_char(C.fechacreacion, ''DD-MM-YYYY'') AS FechaCreacion,
        to_char(C.fechaultimafirma, ''DD-MM-YYYY'') AS FechaUltimaFirma,
        1 AS Semaforo,
      C.idwf,
      ROW_NUMBER() OVER (ORDER BY C.iddocumento DESC) AS RowNum,
      C.rutempresa,
      E.razonsocial,
      CDV.rut,
      PER.nombre,
      PER.appaterno,
      PER.apmaterno,
        (PER.nombre || '' '' || PER.appaterno || '' '' || PER.apmaterno) AS NombreEmpleado,
        REP.personaid AS RutRep,
        REP.nombre AS nombre_rep,
        REP.appaterno AS appaterno_rep,
        REP.apmaterno AS apmaterno_rep,
        (REP.nombre || '' '' || REP.appaterno || '' '' || REP.apmaterno) AS NombreRepresentante';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', CDV.lugarpagoid, LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', CDV.departamentoid, DEP.nombredepartamento';
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', CDV.centrocosto, CC.nombrecentrocosto';
        RAISE NOTICE 'Agregando campo nivel 3: centroscosto';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', CDV.divisionid, DIV.nombredivision';
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', CDV.quintonivelid, QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
    FROM contratos C
        JOIN plantillas PL ON PL.idplantilla = C.idplantilla
        JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc
            AND T.tipousuarioid = ' || p_ptipousuarioid || '
        JOIN empresas E ON E.rutempresa = C.rutempresa
        JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento';

    -- Agregar JOIN a empleados **solo** si el rol es público (2)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
        INNER JOIN empleados Emp ON CDV.rut = Emp.empleadoid
            AND Emp.rolid = ' || v_rolid;
        RAISE NOTICE 'Agregando JOIN de empleados para rol público (2)';
    END IF;

    var_sql := var_sql || '
        LEFT JOIN fichasdocumentos FD ON FD.documentoid = C.iddocumento
       AND FD.idfichaorigen = 2
        JOIN personas PER ON PER.personaid = CDV.rut
        LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento
            AND CF.idestado = C.idestado
        LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante';

    -- JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid
            AND LP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        LEFT JOIN departamentos DEP ON DEP.lugarpagoid = CDV.lugarpagoid
       AND DEP.departamentoid = CDV.departamentoid
            AND DEP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        LEFT JOIN centroscosto CC ON CC.empresaid = C.rutempresa
            AND CC.lugarpagoid = CDV.lugarpagoid
            AND CC.departamentoid = CDV.departamentoid
            AND CC.centrocostoid = CDV.centrocosto';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        LEFT JOIN division DIV ON DIV.empresaid = C.rutempresa
            AND DIV.lugarpagoid = CDV.lugarpagoid
            AND DIV.departamentoid = CDV.departamentoid
            AND DIV.centrocostoid = CDV.centrocosto
            AND DIV.divisionid = CDV.divisionid';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel QN ON QN.empresaid = C.rutempresa
            AND QN.lugarpagoid = CDV.lugarpagoid
            AND QN.departamentoid = CDV.departamentoid
            AND QN.centrocostoid = CDV.centrocosto
            AND QN.divisionid = CDV.divisionid
            AND QN.quintonivelid = CDV.quintonivelid';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Aplicar permisos dinámicos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
            AND ALP.lugarpagoid = CDV.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa
            AND ACC.lugarpagoid = CDV.lugarpagoid
            AND ACC.departamentoid = CDV.departamentoid
            AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
            AND ACC.lugarpagoid = CDV.lugarpagoid
            AND ACC.departamentoid = CDV.departamentoid
            AND ACC.centrocostoid = CDV.centrocosto
            AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
            AND ADIV.lugarpagoid = CDV.lugarpagoid
            AND ADIV.departamentoid = CDV.departamentoid
            AND ADIV.centrocostoid = CDV.centrocosto
            AND ADIV.divisionid = CDV.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
            AND AQN.lugarpagoid = CDV.lugarpagoid
            AND AQN.departamentoid = CDV.departamentoid
            AND AQN.centrocostoid = CDV.centrocosto
            AND AQN.divisionid = CDV.divisionid
            AND AQN.quintonivelid = CDV.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Condiciones WHERE base
    var_sql := var_sql || '
      WHERE C.eliminado = FALSE';

    -- Filtros base
    IF p_pfirmante != '' THEN
        var_sql := var_sql || ' AND (REP.nombre || '' '' || COALESCE(REP.appaterno,'''') || '' '' || COALESCE(REP.apmaterno,'''')) ILIKE ' || quote_literal('%' || p_pfirmante || '%');
    END IF;

    IF p_prutfirmante != '' THEN
        var_sql := var_sql || ' AND REP.personaid = ' || quote_literal(p_prutfirmante);
    END IF;

    IF p_piddocumento != 0 THEN
        var_sql := var_sql || ' AND C.iddocumento = ' || p_piddocumento;
    END IF;

    IF p_pidtipodocumento != 0 THEN
        var_sql := var_sql || ' AND PL.idtipodoc = ' || p_pidtipodocumento;
    END IF;

    -- Validación especial de estado de contrato
    IF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (1,2,3,4,6,8,9,10,11)';
        RAISE NOTICE 'Filtro estado < 0: estados múltiples (1,2,3,4,6,8,9,10,11)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (2,3,10,11)';
        RAISE NOTICE 'Filtro estado = 0: estados (2,3,10,11)';
    ELSIF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || ' AND C.idestado = ' || p_pidestadocontrato;
        RAISE NOTICE 'Filtro estado específico: %', p_pidestadocontrato;
    END IF;

    IF p_pidtipofirma != 0 THEN
        var_sql := var_sql || ' AND C.idtipofirma = ' || p_pidtipofirma;
    END IF;

    IF p_pidproceso != 0 THEN
        var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso;
    END IF;

    IF p_pempresa != '' AND p_pempresa != '0' THEN
        var_sql := var_sql || ' AND C.rutempresa = ' || quote_literal(p_pempresa);
    END IF;

    IF p_prutempresa_input != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ' || quote_literal(p_prutempresa_input);
    END IF;

    IF p_prutempleado != '' THEN
        var_sql := var_sql || ' AND CDV.Rut ILIKE ' || quote_literal('%' || p_prutempleado || '%');
    END IF;

    IF p_pempleado != '' THEN
        var_sql := var_sql || ' AND ((PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, ''''))) ILIKE ' || quote_literal('%' || p_pempleado || '%');
    END IF;

   -- Agregar filtros de fecha condicionalmente
    IF p_fechainicio IS NOT NULL OR p_fechafin IS NOT NULL THEN
        IF p_fechainicio IS NOT NULL AND p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion BETWEEN ''' || p_fechainicio::text || ''' AND ''' || p_fechafin::text || '''';
        ELSIF p_fechainicio IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion >= ''' || p_fechainicio::text || '''';
        ELSIF p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion <= ''' || p_fechafin::text || '''';
        END IF;
    END IF;

    -- Filtros dinámicos por nivel
    IF v_niveles >= 1 AND p_plugarpagoid != '' THEN
        var_sql := var_sql || ' AND CDV.lugarpagoid = ' || quote_literal(p_plugarpagoid);
    END IF;

    IF v_niveles >= 1 AND p_pnombrelugarpago != '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%' || p_pnombrelugarpago || '%');
    END IF;

    IF v_niveles >= 2 AND p_pdepartamentoid != '' THEN
        var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_pdepartamentoid);
    END IF;

    IF v_niveles >= 2 AND p_pnombredepartamento != '' THEN
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%' || p_pnombredepartamento || '%');
    END IF;

    IF v_niveles >= 3 AND p_pcentrocosto != '' THEN
        var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_pcentrocosto);
    END IF;

    IF v_niveles >= 3 AND p_pnombrecentrocosto != '' THEN
        var_sql := var_sql || ' AND CC.nombrecentrocosto ILIKE ' || quote_literal('%' || p_pnombrecentrocosto || '%');
    END IF;

    IF v_niveles >= 4 AND p_pdivisionid != '' THEN
        var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_pdivisionid);
    END IF;

    IF v_niveles >= 4 AND p_pnombredivision != '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%' || p_pnombredivision || '%');
    END IF;

    IF v_niveles = 5 AND p_quintonivelid != '' THEN
        var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid);
    END IF;

    IF v_niveles = 5 AND p_nombrequintonivel != '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%' || p_nombrequintonivel || '%');
    END IF;

    -- Cerrar CTE
    var_sql := var_sql || '
  )
  SELECT
      DT.iddocumento AS "idDocumento",
      DT.idtipodoc AS "idTipoDoc",
      TD.nombretipodoc AS "NombreTipoDoc",
      P.descripcion AS "Proceso",
      CE.descripcion AS "Estado",
      DT.idestado AS "idEstado",
      FT.descripcion AS "Firma",
      DT.fechacreacion AS "FechaCreacion",
      DT.fechaultimafirma AS "FechaUltimaFirma",
      DT.semaforo AS "Semaforo",
      WEP.diasmax AS "DiasEstadoActual",
      DT.idwf AS "idWF",
      DT.rownum AS "RowNum",
      DT.rutempresa AS "RutEmpresa",
      DT.razonsocial AS "RazonSocial",
      DT.rut AS "Rut",
	DT.nombre AS "nombre",
    DT.appaterno AS "appaterno",
    DT.apmaterno AS "apmaterno",
      DT.NombreEmpleado AS "empleado",
      DT.NombreEmpleado AS "NombreEmpleado",
      DT.rutrep AS "RutRep",
      DT.nombre_rep AS "nombre_rep",
      DT.appaterno_rep AS "appaterno_rep",
      DT.apmaterno_rep AS "apmaterno_rep",
      DT.nombrerepresentante AS "NombreRepresentante"';

    -- Agregar campos de niveles en SELECT final
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', DT.lugarpagoid AS "LugarPagoid", DT.nombrelugarpago AS "nombrelugarpago"';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', DT.departamentoid AS "departamentoid", DT.nombredepartamento AS "nombredepartamento"';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', DT.centrocosto AS "CentroCosto", DT.nombrecentrocosto AS "nombrecentrocosto"';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', DT.divisionid AS "divisionid", DT.nombredivision AS "nombredivision"';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', DT.quintonivelid AS "quintonivelid", DT.nombrequintonivel AS "nombrequintonivel"';
    END IF;

    var_sql := var_sql || '
  FROM DocumentosTabla DT
      JOIN tipodocumentos TD ON DT.idtipodoc = TD.idtipodoc
      JOIN procesos P ON P.idproceso = DT.idproceso
      JOIN contratosestados CE ON CE.idestado = DT.idestado
      JOIN firmastipos FT ON FT.idtipofirma = DT.idtipofirma
      LEFT JOIN workflowestadoprocesos WEP ON DT.idwf = WEP.idworkflow
     AND DT.idestado = WEP.idestadowf
  ORDER BY DT.iddocumento DESC
    OFFSET ' || var_offset || '
    LIMIT ' || p_decuantos;

    -- Log de la consulta SQL completa para debug
    IF p_debug = 1 THEN
        RAISE NOTICE '========== CONSULTA SQL COMPLETA (INICIO) ==========';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '========== CONSULTA SQL COMPLETA (FIN) ==========';
    END IF;

    RAISE NOTICE 'Ejecutando consulta de listado con paginación';

    -- Abrir cursor con los resultados
    OPEN p_refcursor FOR EXECUTE var_sql;
  RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_documentosvigentes_listado_porprocesos_2: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_documentosvigentes_listado_porprocesos_2: %', SQLERRM;
END;
$BODY$;
-- FUNCTION: public.sp_documentosvigentes_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, integer)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_total(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, text, text, text, text, text, text, text, text, text, text, text, text, text, text, integer);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_total(
	p_refcursor refcursor,
	p_tipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_iddocumento integer,
	p_idtipodocumento integer,
	p_idestadocontrato integer,
	p_idtipofirma integer,
	p_idproceso integer,
	p_firmante text,
	p_rutfirmante text,
	p_lugarpagoid text,
	p_nombrelugarpago text,
	p_departamentoid text,
	p_nombredepartamento text,
	p_centrocosto text,
	p_nombrecentrocosto text,
	p_divisionid text,
	p_nombredivision text,
	p_quintonivelid text,
	p_nombrequintonivel text,
	p_usuarioid text,
	p_empresa text,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql TEXT;
    v_niveles integer;
    v_rolid integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentosvigentes_total - Usuario: ' || COALESCE(p_usuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_usuarioid;
    RAISE NOTICE 'Rol del usuario: %', v_rolid;

    -- Construcción de la subconsulta
    var_sql := '
        WITH DocumentosTabla AS (
            SELECT C.iddocumento
            FROM contratos C
            INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla
            INNER JOIN tiposdocumentosxperfil TDP ON PL.idplantilla = TDP.idtipodoc AND TDP.tipousuarioid = ' || p_tipousuarioid || '
            INNER JOIN empresas E ON E.rutempresa = C.rutempresa
            INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento
            INNER JOIN personas PER ON PER.personaid = CDV.rut
            LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND CF.idestado = 2
            LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante';

    -- JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
            LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid AND LP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
            LEFT JOIN departamentos DEP ON DEP.departamentoid = CDV.departamentoid AND DEP.lugarpagoid = CDV.lugarpagoid AND DEP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
            LEFT JOIN centroscosto CCO ON CCO.centrocostoid = CDV.centrocosto AND CCO.lugarpagoid = CDV.lugarpagoid AND CCO.departamentoid = CDV.departamentoid AND CCO.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
            LEFT JOIN division DIV ON DIV.divisionid = CDV.divisionid AND DIV.lugarpagoid = CDV.lugarpagoid AND DIV.departamentoid = CDV.departamentoid AND DIV.centrocostoid = CDV.centrocosto AND DIV.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
            LEFT JOIN quinto_nivel QN ON QN.quintonivelid = CDV.quintonivelid AND QN.lugarpagoid = CDV.lugarpagoid AND QN.departamentoid = CDV.departamentoid AND QN.centrocostoid = CDV.centrocosto AND QN.divisionid = CDV.divisionid AND QN.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
                AND ALP.lugarpagoid = CDV.lugarpagoid
                AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa
                AND ACC.lugarpagoid = CDV.lugarpagoid
                AND ACC.departamentoid = CDV.departamentoid
                AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
                AND ACC.lugarpagoid = CDV.lugarpagoid
                AND ACC.departamentoid = CDV.departamentoid
                AND ACC.centrocostoid = CDV.centrocosto
                AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
                AND ADIV.lugarpagoid = CDV.lugarpagoid
                AND ADIV.departamentoid = CDV.departamentoid
                AND ADIV.centrocostoid = CDV.centrocosto
                AND ADIV.divisionid = CDV.divisionid
                AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
            INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
                AND AQN.lugarpagoid = CDV.lugarpagoid
                AND AQN.departamentoid = CDV.departamentoid
                AND AQN.centrocostoid = CDV.centrocosto
                AND AQN.divisionid = CDV.divisionid
                AND AQN.quintonivelid = CDV.quintonivelid
                AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Aplicar filtro por ROL si es necesario (2 = Público)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
            INNER JOIN empleados EMP ON CDV.rut = EMP.empleadoid AND EMP.rolid = ' || v_rolid;
        RAISE NOTICE 'Agregando filtro por ROL: %', v_rolid;
    END IF;

    -- WHERE base
    var_sql := var_sql || '
            WHERE C.eliminado = false
              AND TDP.tipousuarioid = ' || p_tipousuarioid;

    -- Filtros dinámicos (orden como SQL Server)
    -- Filtros de firmante (primero)
    IF p_firmante <> '' THEN
        var_sql := var_sql || ' AND (REP.nombre || '' '' || REP.appaterno || '' '' || REP.apmaterno) ILIKE ' || quote_literal('%' || p_firmante || '%');
    END IF;
    
    IF p_rutfirmante <> '' THEN
        var_sql := var_sql || ' AND REP.personaid ILIKE ' || quote_literal('%' || p_rutfirmante || '%');
    END IF;
    
    -- Filtros de documento
    IF p_iddocumento <> 0 THEN
        var_sql := var_sql || ' AND C.iddocumento = ' || p_iddocumento;
    END IF;
    
    IF p_idtipodocumento <> 0 THEN
        var_sql := var_sql || ' AND PL.idtipodoc = ' || p_idtipodocumento;
    END IF;
    
    -- Filtro de estado (con lógica especial como SQL Server)
    IF p_idestadocontrato > 0 THEN
        var_sql := var_sql || ' AND C.idestado = ' || p_idestadocontrato;
    ELSIF p_idestadocontrato < 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (1,2,3,6,8,9,10,11)';
    ELSIF p_idestadocontrato = 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (2,3,10,11)';
    END IF;
    
    IF p_idtipofirma <> 0 THEN
        var_sql := var_sql || ' AND C.idtipofirma = ' || p_idtipofirma;
    END IF;
    
    IF p_idproceso <> 0 THEN
        var_sql := var_sql || ' AND C.idproceso = ' || p_idproceso;
    END IF;

    -- Filtros dinámicos por nivel
    IF v_niveles >= 1 AND p_lugarpagoid <> '' THEN
        var_sql := var_sql || ' AND CDV.lugarpagoid = ' || quote_literal(p_lugarpagoid);
    END IF;
    
    IF v_niveles >= 1 AND p_nombrelugarpago <> '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%' || p_nombrelugarpago || '%');
    END IF;
    
    IF v_niveles >= 2 AND p_departamentoid <> '' THEN
        var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_departamentoid);
    END IF;
    
    IF v_niveles >= 2 AND p_nombredepartamento <> '' THEN
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%' || p_nombredepartamento || '%');
    END IF;

    IF v_niveles >= 3 AND p_centrocosto <> '' THEN
        var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_centrocosto);
    END IF;

    IF v_niveles >= 3 AND p_nombrecentrocosto <> '' THEN
        var_sql := var_sql || ' AND CCO.nombrecentrocosto ILIKE ' || quote_literal('%' || p_nombrecentrocosto || '%');
    END IF;

    IF v_niveles >= 4 AND p_divisionid <> '' THEN
        var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_divisionid);
    END IF;

    IF v_niveles >= 4 AND p_nombredivision <> '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%' || p_nombredivision || '%');
    END IF;

    IF v_niveles = 5 AND p_quintonivelid <> '' THEN
        var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid);
    END IF;

    IF v_niveles = 5 AND p_nombrequintonivel <> '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%' || p_nombrequintonivel || '%');
    END IF;

    -- Filtro de empresa (al final como SQL Server)
    IF p_empresa <> '' AND p_empresa <> '0' THEN
        var_sql := var_sql || ' AND C.rutempresa = ' || quote_literal(p_empresa);
    END IF;

    -- Cierre del CTE + cálculo
    var_sql := var_sql || ')
        SELECT 
            CEIL(COUNT(*)::NUMERIC / ' || p_decuantos || ')::INT AS "total",
            COUNT(*)::INT AS "totalreg"
        FROM DocumentosTabla';

    -- Debug
    IF p_debug = 1 THEN
        RAISE NOTICE 'Consulta ejecutada: %', var_sql;
    END IF;

    -- Abrir cursor
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_documentosvigentes_total: %', SQLERRM;
        OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
        RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_documentosvigentes_total_porprocesos(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, date, date, smallint)

-- DROP FUNCTION IF EXISTS public.sp_documentosvigentes_total_porprocesos(refcursor, integer, integer, numeric, integer, integer, integer, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, date, date, smallint);

CREATE OR REPLACE FUNCTION public.sp_documentosvigentes_total_porprocesos(
    p_refcursor refcursor,
    p_ptipousuarioid integer,
    p_pagina integer,
    p_decuantos numeric,
    p_piddocumento integer,
    p_pidtipodocumento integer,
    p_pidestadocontrato integer,
    p_pidtipofirma integer,
    p_pidproceso integer,
    p_pfirmante character varying,
    p_prutfirmante character varying,
    p_plugarpagoid character varying,
    p_pnombrelugarpago character varying,
    p_pdepartamentoid character varying,
    p_pnombredepartamento character varying,
    p_pcentrocosto character varying,
    p_pnombrecentrocosto character varying,
    p_pdivisionid character varying,
    p_pnombredivision character varying,
    p_quintonivelid character varying,
    p_nombrequintonivel character varying,
    p_pusuarioid character varying,
    p_pempresa character varying,
    p_prutempresa_input character varying,
    p_prutempleado character varying,
    p_pempleado character varying,
    p_fechainicio date,
    p_fechafin date,
    p_debug smallint DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_offset INTEGER := (p_pagina - 1) * p_decuantos;
    v_rolid INTEGER;
    v_niveles INTEGER;
    var_sql TEXT;
    var_log_message TEXT;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_documentosvigentes_total_porprocesos2 - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol del usuario
    SELECT COALESCE(rolid, 2) INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;

    -- ====== Construcción dinámica de SQL (igual al listado y con totales para paginado) ======
    -- Campos base del SELECT (siempre presentes)
    var_sql := '
  WITH DocumentosTabla AS (
    SELECT
      COUNT(*) OVER () AS total';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', CDV.lugarpagoid, LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campo nivel 1: lugarespago';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', CDV.departamentoid, DEP.nombredepartamento';
        RAISE NOTICE 'Agregando campo nivel 2: departamentos';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', CDV.centrocosto, CC.nombrecentrocosto';
        RAISE NOTICE 'Agregando campo nivel 3: centroscosto';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', CDV.divisionid, DIV.nombredivision';
        RAISE NOTICE 'Agregando campo nivel 4: division';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', CDV.quintonivelid, QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campo nivel 5: quinto_nivel';
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
    FROM contratos C
        JOIN plantillas PL ON PL.idplantilla = C.idplantilla
        JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc
            AND T.tipousuarioid = ' || p_ptipousuarioid || '
        JOIN empresas E ON E.rutempresa = C.rutempresa
        JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento';

    -- Agregar JOIN a empleados solo si el rol es público (2)
    IF v_rolid = 2 THEN
        var_sql := var_sql || '
        INNER JOIN empleados Emp ON CDV.rut = Emp.empleadoid
            AND Emp.rolid = ' || v_rolid;
        RAISE NOTICE 'Agregando JOIN de empleados para rol público (2)';
    END IF;

    var_sql := var_sql || '
        LEFT JOIN fichasdocumentos FD ON FD.documentoid = C.iddocumento
            AND FD.idfichaorigen = 2
        JOIN personas PER ON PER.personaid = CDV.rut
        LEFT JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento
            AND CF.idestado = C.idestado
        LEFT JOIN personas REP ON REP.personaid = CF.rutfirmante';

    -- JOINs dinámicos por nivel
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        LEFT JOIN lugarespago LP ON LP.lugarpagoid = CDV.lugarpagoid
            AND LP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        LEFT JOIN departamentos DEP ON DEP.lugarpagoid = CDV.lugarpagoid
            AND DEP.departamentoid = CDV.departamentoid
            AND DEP.empresaid = C.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        LEFT JOIN centroscosto CC ON CC.empresaid = C.rutempresa
            AND CC.lugarpagoid = CDV.lugarpagoid
            AND CC.departamentoid = CDV.departamentoid
            AND CC.centrocostoid = CDV.centrocosto';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        LEFT JOIN division DIV ON DIV.empresaid = C.rutempresa
            AND DIV.lugarpagoid = CDV.lugarpagoid
            AND DIV.departamentoid = CDV.departamentoid
            AND DIV.centrocostoid = CDV.centrocosto
            AND DIV.divisionid = CDV.divisionid';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        LEFT JOIN quinto_nivel QN ON QN.empresaid = C.rutempresa
            AND QN.lugarpagoid = CDV.lugarpagoid
            AND QN.departamentoid = CDV.departamentoid
            AND QN.centrocostoid = CDV.centrocosto
            AND QN.divisionid = CDV.divisionid
            AND QN.quintonivelid = CDV.quintonivelid';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Aplicar permisos dinámicos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = C.rutempresa
            AND ALP.lugarpagoid = CDV.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = C.rutempresa
            AND ACC.lugarpagoid = CDV.lugarpagoid
            AND ACC.departamentoid = CDV.departamentoid
            AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = C.rutempresa
            AND ACC.lugarpagoid = CDV.lugarpagoid
            AND ACC.departamentoid = CDV.departamentoid
            AND ACC.centrocostoid = CDV.centrocosto
            AND ACC.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = C.rutempresa
            AND ADIV.lugarpagoid = CDV.lugarpagoid
            AND ADIV.departamentoid = CDV.departamentoid
            AND ADIV.centrocostoid = CDV.centrocosto
            AND ADIV.divisionid = CDV.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = C.rutempresa
            AND AQN.lugarpagoid = CDV.lugarpagoid
            AND AQN.departamentoid = CDV.departamentoid
            AND AQN.centrocostoid = CDV.centrocosto
            AND AQN.divisionid = CDV.divisionid
            AND AQN.quintonivelid = CDV.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_pusuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
    END IF;

    -- Condiciones WHERE base
    var_sql := var_sql || '
      WHERE C.eliminado = FALSE';

    -- Filtros base
    IF p_pfirmante != '' THEN
        var_sql := var_sql || ' AND (REP.nombre || '' '' || COALESCE(REP.appaterno,'''') || '' '' || COALESCE(REP.apmaterno,'''')) ILIKE ' || quote_literal('%' || p_pfirmante || '%');
    END IF;

    IF p_prutfirmante != '' THEN
        var_sql := var_sql || ' AND REP.personaid = ' || quote_literal(p_prutfirmante);
    END IF;

    IF p_piddocumento != 0 THEN
        var_sql := var_sql || ' AND C.iddocumento = ' || p_piddocumento;
    END IF;

    IF p_pidtipodocumento != 0 THEN
        var_sql := var_sql || ' AND PL.idtipodoc = ' || p_pidtipodocumento;
    END IF;

    -- Validación especial de estado de contrato
    IF p_pidestadocontrato < 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (1,2,3,4,6,8,9,10,11)';
        RAISE NOTICE 'Filtro estado < 0: estados múltiples (1,2,3,4,6,8,9,10,11)';
    ELSIF p_pidestadocontrato = 0 THEN
        var_sql := var_sql || ' AND C.idestado IN (2,3,10,11)';
        RAISE NOTICE 'Filtro estado = 0: estados (2,3,10,11)';
    ELSIF p_pidestadocontrato > 0 THEN
        var_sql := var_sql || ' AND C.idestado = ' || p_pidestadocontrato;
        RAISE NOTICE 'Filtro estado específico: %', p_pidestadocontrato;
    END IF;

    IF p_pidtipofirma != 0 THEN
        var_sql := var_sql || ' AND C.idtipofirma = ' || p_pidtipofirma;
    END IF;

    IF p_pidproceso != 0 THEN
        var_sql := var_sql || ' AND C.idproceso = ' || p_pidproceso;
    END IF;

    IF p_pempresa != '' AND p_pempresa != '0' THEN
        var_sql := var_sql || ' AND C.rutempresa = ' || quote_literal(p_pempresa);
    END IF;

    IF p_prutempresa_input != '' THEN
        var_sql := var_sql || ' AND C.rutempresa = ' || quote_literal(p_prutempresa_input);
    END IF;

    IF p_prutempleado != '' THEN
        var_sql := var_sql || ' AND CDV.Rut ILIKE ' || quote_literal('%' || p_prutempleado || '%');
    END IF;

    IF p_pempleado != '' THEN
        var_sql := var_sql || ' AND ((PER.nombre || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, ''''))) ILIKE ' || quote_literal('%' || p_pempleado || '%');
    END IF;

    -- Agregar filtros de fecha condicionalmente
    IF p_fechainicio IS NOT NULL OR p_fechafin IS NOT NULL THEN
        IF p_fechainicio IS NOT NULL AND p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion BETWEEN ''' || p_fechainicio::text || ''' AND ''' || p_fechafin::text || '''';
        ELSIF p_fechainicio IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion >= ''' || p_fechainicio::text || '''';
        ELSIF p_fechafin IS NOT NULL THEN
            var_sql := var_sql || ' AND C.fechacreacion <= ''' || p_fechafin::text || '''';
        END IF;
    END IF;

    -- Filtros dinámicos por nivel
    IF v_niveles >= 1 AND p_plugarpagoid != '' THEN
        var_sql := var_sql || ' AND CDV.lugarpagoid = ' || quote_literal(p_plugarpagoid);
    END IF;

    IF v_niveles >= 1 AND p_pnombrelugarpago != '' THEN
        var_sql := var_sql || ' AND LP.nombrelugarpago ILIKE ' || quote_literal('%' || p_pnombrelugarpago || '%');
    END IF;

    IF v_niveles >= 2 AND p_pdepartamentoid != '' THEN
        var_sql := var_sql || ' AND CDV.departamentoid = ' || quote_literal(p_pdepartamentoid);
    END IF;

    IF v_niveles >= 2 AND p_pnombredepartamento != '' THEN
        var_sql := var_sql || ' AND DEP.nombredepartamento ILIKE ' || quote_literal('%' || p_pnombredepartamento || '%');
    END IF;

    IF v_niveles >= 3 AND p_pcentrocosto != '' THEN
        var_sql := var_sql || ' AND CDV.centrocosto = ' || quote_literal(p_pcentrocosto);
    END IF;

    IF v_niveles >= 3 AND p_pnombrecentrocosto != '' THEN
        var_sql := var_sql || ' AND CC.nombrecentrocosto ILIKE ' || quote_literal('%' || p_pnombrecentrocosto || '%');
    END IF;

    IF v_niveles >= 4 AND p_pdivisionid != '' THEN
        var_sql := var_sql || ' AND CDV.divisionid = ' || quote_literal(p_pdivisionid);
    END IF;

    IF v_niveles >= 4 AND p_pnombredivision != '' THEN
        var_sql := var_sql || ' AND DIV.nombredivision ILIKE ' || quote_literal('%' || p_pnombredivision || '%');
    END IF;

    IF v_niveles = 5 AND p_quintonivelid != '' THEN
        var_sql := var_sql || ' AND CDV.quintonivelid = ' || quote_literal(p_quintonivelid);
    END IF;

    IF v_niveles = 5 AND p_nombrequintonivel != '' THEN
        var_sql := var_sql || ' AND QN.nombrequintonivel ILIKE ' || quote_literal('%' || p_nombrequintonivel || '%');
    END IF;

    -- Cerrar CTE y seleccionar con totales y paginado
    var_sql := var_sql || '
  )
  SELECT
      CEIL((MAX(DT.total))::numeric / ' || p_decuantos || ')::int AS "total",
      (MAX(DT.total))::numeric AS "totalreg"
  FROM DocumentosTabla DT;';

    -- Log de la consulta SQL completa para debug
    IF p_debug = 1 THEN
        RAISE NOTICE '========== CONSULTA SQL COMPLETA (INICIO) ==========';
        RAISE NOTICE '%', var_sql;
        RAISE NOTICE '========== CONSULTA SQL COMPLETA (FIN) ==========';
    END IF;

    RAISE NOTICE 'Ejecutando consulta de listado con totales y paginación';

    -- Abrir cursor con los resultados
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_documentosvigentes_total_porprocesos2: %', SQLERRM;
END;
$BODY$;


-- FUNCTION: public.sp_empleados_agregarconusuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, date, character varying, integer, character varying, character varying, integer, integer, integer, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_empleados_agregarconusuario(refcursor, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, date, character varying, integer, character varying, character varying, integer, integer, integer, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_empleados_agregarconusuario(
	p_refcursor refcursor,
	ppersonaid character varying,
	pnacionalidad character varying,
	pnombre character varying,
	pappaterno character varying,
	papmaterno character varying,
	pcorreo character varying,
	pcorreoinstitucional character varying,
	pdireccion character varying,
	pciudad character varying,
	pcomuna character varying,
	pfechanacimiento date,
	pestadocivil_txt character varying,
	prolid integer,
	clave character varying,
	estado character varying,
	ptipocorreo integer,
	ptipofirma integer,
	ptipousuario integer,
	pregion character varying,
	pfono character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error       integer := 0;
    var_lmensaje    text := '';
    var_largo       integer;
    var_claveTemp   varchar(62);
    var_RutEmpresa  varchar(50);
    var_LP          varchar(50);
    var_DP          varchar(50);
    var_CC          varchar(50);
    var_DI          varchar(50);
    var_QN          varchar(50);
    v_niveles       integer;
    -- Variables para replicar fnCustomPass
    var_chars       text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    var_numbers     text := '0123456789';
    var_strchars    text;
    var_strpass     text := '';
    var_index       integer;
    var_cont        integer := 0;
    -- Convertir pestadocivil (acepta '')
    var_estadociv   integer := CASE WHEN pestadocivil_txt = '' THEN NULL ELSE pestadocivil_txt::integer END;
BEGIN
    -- Asegurar mayúsculas en RUT
    ppersonaid := upper(ppersonaid);

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;

    -- SECCIÓN PERSONAS
    IF NOT EXISTS (SELECT 1 FROM personas WHERE personaid = ppersonaid) THEN
        INSERT INTO personas(
            personaid, nacionalidad, nombre, appaterno, apmaterno,
            correo, correoinstitucional, direccion, ciudad, comuna,
            fechanacimiento, estadocivil, eliminado, region, fono
        ) VALUES (
            ppersonaid, pnacionalidad, pnombre, pappaterno, papmaterno,
            pcorreo, pcorreoinstitucional, pdireccion, pciudad, pcomuna,
            pfechanacimiento, var_estadociv, false, pregion, pfono
        );
    ELSE
        UPDATE personas SET
            nombre               = pnombre,
            appaterno            = pappaterno,
            apmaterno            = papmaterno,
            nacionalidad         = pnacionalidad,
            correo               = pcorreo,
            correoinstitucional  = pcorreoinstitucional,
            direccion            = pdireccion,
            ciudad               = pciudad,
            comuna               = pcomuna,
            fechanacimiento      = pfechanacimiento,
            estadocivil          = var_estadociv,
            eliminado            = false,
            region               = pregion,
            fono                 = pfono
        WHERE personaid = ppersonaid;
    END IF;

    -- SECCIÓN EMPLEADOS
    IF NOT EXISTS (SELECT 1 FROM empleados WHERE empleadoid = ppersonaid) THEN
        -- Obtener todos los niveles disponibles dinámicamente
        -- rutempresa viene de contratos, los demás de contratodatosvariables
        IF v_niveles = 1 THEN
            SELECT c.rutempresa, cdv.lugarpagoid
            INTO var_RutEmpresa, var_LP
            FROM contratos c
            JOIN contratodatosvariables cdv ON c.iddocumento = cdv.iddocumento
            WHERE cdv.rut = ppersonaid
            ORDER BY c.iddocumento DESC LIMIT 1;
        ELSIF v_niveles = 2 THEN
            SELECT c.rutempresa, cdv.lugarpagoid, cdv.departamentoid
            INTO var_RutEmpresa, var_LP, var_DP
            FROM contratos c
            JOIN contratodatosvariables cdv ON c.iddocumento = cdv.iddocumento
            WHERE cdv.rut = ppersonaid
            ORDER BY c.iddocumento DESC LIMIT 1;
        ELSIF v_niveles = 3 THEN
            SELECT c.rutempresa, cdv.lugarpagoid, cdv.departamentoid, cdv.centrocosto
            INTO var_RutEmpresa, var_LP, var_DP, var_CC
            FROM contratos c
            JOIN contratodatosvariables cdv ON c.iddocumento = cdv.iddocumento
            WHERE cdv.rut = ppersonaid
            ORDER BY c.iddocumento DESC LIMIT 1;
        ELSIF v_niveles = 4 THEN
            SELECT c.rutempresa, cdv.lugarpagoid, cdv.departamentoid, cdv.centrocosto, cdv.divisionid
            INTO var_RutEmpresa, var_LP, var_DP, var_CC, var_DI
            FROM contratos c
            JOIN contratodatosvariables cdv ON c.iddocumento = cdv.iddocumento
            WHERE cdv.rut = ppersonaid
            ORDER BY c.iddocumento DESC LIMIT 1;
        ELSIF v_niveles = 5 THEN
            SELECT c.rutempresa, cdv.lugarpagoid, cdv.departamentoid, cdv.centrocosto, cdv.divisionid, cdv.quintonivelid
            INTO var_RutEmpresa, var_LP, var_DP, var_CC, var_DI, var_QN
            FROM contratos c
            JOIN contratodatosvariables cdv ON c.iddocumento = cdv.iddocumento
            WHERE cdv.rut = ppersonaid
            ORDER BY c.iddocumento DESC LIMIT 1;
        END IF;
        
        -- Insertar empleado con niveles dinámicos
        IF v_niveles = 1 THEN
            INSERT INTO empleados(
                empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid
            ) VALUES (
                ppersonaid, prolid, estado, var_RutEmpresa, var_LP
            );
        ELSIF v_niveles = 2 THEN
            INSERT INTO empleados(
                empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid, departamentoid
            ) VALUES (
                ppersonaid, prolid, estado, var_RutEmpresa, var_LP, var_DP
            );
        ELSIF v_niveles = 3 THEN
            INSERT INTO empleados(
                empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid, departamentoid, centrocostoid
            ) VALUES (
                ppersonaid, prolid, estado, var_RutEmpresa, var_LP, var_DP, var_CC
            );
        ELSIF v_niveles = 4 THEN
            INSERT INTO empleados(
                empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid, departamentoid, centrocostoid, divisionid
            ) VALUES (
                ppersonaid, prolid, estado, var_RutEmpresa, var_LP, var_DP, var_CC, var_DI
            );
        ELSIF v_niveles = 5 THEN
            INSERT INTO empleados(
                empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid
            ) VALUES (
                ppersonaid, prolid, estado, var_RutEmpresa, var_LP, var_DP, var_CC, var_DI, var_QN
            );
        END IF;
    ELSE
        -- Obtener datos existentes del empleado según niveles disponibles
        IF v_niveles = 1 THEN
            SELECT rutempresa, lugarpagoid
            INTO var_RutEmpresa, var_LP
            FROM empleados WHERE empleadoid = ppersonaid;
        ELSIF v_niveles = 2 THEN
            SELECT rutempresa, lugarpagoid, departamentoid
            INTO var_RutEmpresa, var_LP, var_DP
            FROM empleados WHERE empleadoid = ppersonaid;
        ELSIF v_niveles = 3 THEN
            SELECT rutempresa, lugarpagoid, departamentoid, centrocostoid
            INTO var_RutEmpresa, var_LP, var_DP, var_CC
            FROM empleados WHERE empleadoid = ppersonaid;
        ELSIF v_niveles = 4 THEN
            SELECT rutempresa, lugarpagoid, departamentoid, centrocostoid, divisionid
            INTO var_RutEmpresa, var_LP, var_DP, var_CC, var_DI
            FROM empleados WHERE empleadoid = ppersonaid;
        ELSIF v_niveles = 5 THEN
            SELECT rutempresa, lugarpagoid, departamentoid, centrocostoid, divisionid, quintonivelid
            INTO var_RutEmpresa, var_LP, var_DP, var_CC, var_DI, var_QN
            FROM empleados WHERE empleadoid = ppersonaid;
        END IF;
        
        -- Actualizar empleado según niveles disponibles
        IF var_RutEmpresa IS NULL OR var_LP IS NULL THEN
            IF v_niveles = 1 THEN
                UPDATE empleados SET
                    rolid            = prolid,
                    idestadoempleado = estado,
                    rutempresa       = var_RutEmpresa,
                    lugarpagoid      = var_LP
                WHERE empleadoid = ppersonaid;
            ELSIF v_niveles = 2 THEN
                UPDATE empleados SET
                    rolid            = prolid,
                    idestadoempleado = estado,
                    rutempresa       = var_RutEmpresa,
                    lugarpagoid      = var_LP,
                    departamentoid   = var_DP
                WHERE empleadoid = ppersonaid;
            ELSIF v_niveles = 3 THEN
                UPDATE empleados SET
                    rolid            = prolid,
                    idestadoempleado = estado,
                    rutempresa       = var_RutEmpresa,
                    lugarpagoid      = var_LP,
                    departamentoid   = var_DP,
                    centrocostoid    = var_CC
                WHERE empleadoid = ppersonaid;
            ELSIF v_niveles = 4 THEN
                UPDATE empleados SET
                    rolid            = prolid,
                    idestadoempleado = estado,
                    rutempresa       = var_RutEmpresa,
                    lugarpagoid      = var_LP,
                    departamentoid   = var_DP,
                    centrocostoid    = var_CC,
                    divisionid       = var_DI
                WHERE empleadoid = ppersonaid;
            ELSIF v_niveles = 5 THEN
                UPDATE empleados SET
                    rolid            = prolid,
                    idestadoempleado = estado,
                    rutempresa       = var_RutEmpresa,
                    lugarpagoid      = var_LP,
                    departamentoid   = var_DP,
                    centrocostoid    = var_CC,
                    divisionid       = var_DI,
                    quintonivelid    = var_QN
                WHERE empleadoid = ppersonaid;
            END IF;
        ELSE
            UPDATE empleados SET
                rolid            = prolid,
                idestadoempleado = estado
            WHERE empleadoid = ppersonaid;
        END IF;
    END IF;

    -- SECCIÓN USUARIOS
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE usuarioid = ppersonaid) THEN
        -- Obtener longitud de clave
        SELECT parametro::integer INTO var_largo
        FROM parametros WHERE idparametro = 'largoClaveMin';
        -- Preparar conjunto de caracteres (op = 'CN')
        var_strchars := var_chars || var_numbers;
        -- Generar contraseña aleatoria
        var_cont := 0;
        var_strpass := '';
        LOOP
            EXIT WHEN var_cont >= var_largo;
            var_index := ceil(random() * length(var_strchars));
            var_strpass := var_strpass || substring(var_strchars, var_index, 1);
            var_cont := var_cont + 1;
        END LOOP;
        var_claveTemp := var_strpass;
        -- Insertar usuario con hash SHA256
        INSERT INTO usuarios(
            usuarioid, nombreusuario, clave, ultimavez, estado,
            bloqueado, cambiarclave, idfirma, loginexterno,
            tipousuarioid, rolid, clavetemporal,
            notifnuevousuario, idestadoempleado, rutempresa
        ) VALUES (
            ppersonaid, '',
            encode(digest(var_claveTemp::bytea, 'sha256'), 'hex'),
            now(), 1, 0, 1,
            1, 0, pTipoUsuario, prolid, var_claveTemp,
            1, estado, var_RutEmpresa
        );
    END IF;

    -- Abrir cursor con resultado
    OPEN p_refcursor FOR SELECT var_error AS "error", var_lmensaje AS "mensaje";
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    var_error := 1;
    var_lmensaje := SQLERRM;
    OPEN p_refcursor FOR SELECT var_error AS "error", var_lmensaje AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;
-- FUNCTION: public.sp_empleados_obtener(refcursor, character varying)

-- DROP FUNCTION IF EXISTS public.sp_empleados_obtener(refcursor, character varying);

CREATE OR REPLACE FUNCTION public.sp_empleados_obtener(
	p_refcursor refcursor,
	p_empleadoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    OPEN p_refcursor FOR
        SELECT 
            P.nombre,
            P.appaterno,
            P.apmaterno,
            P.personaid,
            P.personaid AS empleadoid,
            COALESCE(P.nombre, '') || ' ' || COALESCE(P.appaterno, '') || ' ' || COALESCE(P.apmaterno, '') AS nombretrabajador,
            TO_CHAR(P.fechanacimiento, 'DD-MM-YYYY') AS fechanacimiento,
            P.nacionalidad,
            P.direccion,
            P.comuna,
            P.ciudad,
            P.ciudad AS ciudad2,
            P.region,
            P.estadocivil AS "idEstadoCivil",
            EC.Descripcion,
            E.rolid,
            R.Descripcion AS DescripcionR,
            P.correo,
            P.correoinstitucional,
            E.idEstadoEmpleado AS "idEstadoEmpleado",
            P.correoinstitucional AS correoinstitucional2,
            P.fono,
            ROW_NUMBER() OVER (ORDER BY P.personaid) AS RowNum
        FROM Empleados E 
        INNER JOIN personas P ON E.empleadoid = P.personaid
        LEFT JOIN Roles R ON E.rolid = R.rolid
        LEFT JOIN EstadoCivil EC ON P.estadocivil = EC.idEstadoCivil
        LEFT JOIN EstadosEmpleados EE ON E.idEstadoEmpleado = EE.idEstadoEmpleado
        WHERE P.personaid = p_empleadoid;
        
    RETURN p_refcursor;
END;
$BODY$;


	
-- FUNCTION: public.sp_g_accesoxusuario_acctodo_departamento(refcursor, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_acctodo_departamento(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_acctodo_departamento(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying)
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
    
    -- Nivel 3: Insertar permisos para centros de costo
    IF v_niveles >= 3 THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        LEFT JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = p_usuarioid
                                                 AND ACC.empresaid = p_empresaid
                                                 AND ACC.lugarpagoid = LP.lugarpagoid
                                                 AND ACC.departamentoid = DP.departamentoid
                                                 AND ACC.centrocostoid = CC.centrocostoid
        WHERE ACC.centrocostoid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
        LEFT JOIN g_accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                   AND ACC.empresaid = p_empresaid
                                                   AND ACC.lugarpagoid = LP.lugarpagoid
                                                   AND ACC.departamentoid = DP.departamentoid
                                                   AND ACC.centrocostoid = CC.centrocostoid
                                                   AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid
        AND DP.departamentoid = p_departamentoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
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
        AND DP.departamentoid = p_departamentoid;
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


-- FUNCTION: public.sp_g_accesoxusuario_acctodo_empresa(refcursor, character varying, character varying)

DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_acctodo_empresa(refcursor, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_acctodo_empresa(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying)
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
    
    -- Nivel 1: Insertar permisos para lugares de pago
    IF v_niveles >= 1 THEN
        INSERT INTO g_accesoxusuariolugarespago (usuarioid, empresaid, lugarpagoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid
        FROM lugarespago AS LP
        LEFT JOIN g_accesoxusuariolugarespago AS ACCLP ON ACCLP.usuarioid = p_usuarioid
                                                        AND ACCLP.empresaid = p_empresaid
                                                        AND ACCLP.lugarpagoid = LP.lugarpagoid
        WHERE ACCLP.lugarpagoid IS NULL 
        AND LP.empresaid = p_empresaid;
    END IF;
    
    -- Nivel 2: Insertar permisos para departamentos
    IF v_niveles >= 2 THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        SELECT p_usuarioid, p_empresaid, DP.lugarpagoid, DP.departamentoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        LEFT JOIN g_accesoxusuariodepartamento AS ACDP ON ACDP.usuarioid = p_usuarioid
                                                         AND ACDP.empresaid = p_empresaid
                                                         AND ACDP.lugarpagoid = LP.lugarpagoid
                                                         AND ACDP.departamentoid = DP.departamentoid
        WHERE ACDP.departamentoid IS NULL
        AND LP.empresaid = p_empresaid;
    END IF;
    
    -- Nivel 3: Insertar permisos para centros de costo
    IF v_niveles >= 3 THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        LEFT JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = p_usuarioid
                                                 AND ACC.empresaid = p_empresaid
                                                 AND ACC.lugarpagoid = LP.lugarpagoid
                                                 AND ACC.departamentoid = DP.departamentoid
                                                 AND ACC.centrocostoid = CC.centrocostoid
        WHERE ACC.centrocostoid IS NULL
        AND LP.empresaid = p_empresaid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
        LEFT JOIN g_accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                   AND ACC.empresaid = p_empresaid
                                                   AND ACC.lugarpagoid = LP.lugarpagoid
                                                   AND ACC.departamentoid = DP.departamentoid
                                                   AND ACC.centrocostoid = CC.centrocostoid
                                                   AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
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
        AND LP.empresaid = p_empresaid;
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


-- FUNCTION: public.sp_g_accesoxusuario_acctodo_lugarpago(refcursor, character varying, character varying, character varying)

DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_acctodo_lugarpago(refcursor, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_acctodo_lugarpago(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying)
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
    
    -- Nivel 2: Insertar permisos para departamentos
    IF v_niveles >= 2 THEN
        INSERT INTO g_accesoxusuariodepartamento (usuarioid, empresaid, lugarpagoid, departamentoid)
        SELECT p_usuarioid, p_empresaid, DP.lugarpagoid, DP.departamentoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        LEFT JOIN g_accesoxusuariodepartamento AS ACDP ON ACDP.usuarioid = p_usuarioid
                                                         AND ACDP.empresaid = p_empresaid
                                                         AND ACDP.lugarpagoid = LP.lugarpagoid
                                                         AND ACDP.departamentoid = DP.departamentoid
        WHERE ACDP.departamentoid IS NULL
        AND LP.lugarpagoid = p_lugarpagoid
        AND LP.empresaid = p_empresaid;
    END IF;
    
    -- Nivel 3: Insertar permisos para centros de costo
    IF v_niveles >= 3 THEN
        INSERT INTO g_accesoxusuarioccosto (usuarioid, empresaid, lugarpagoid, departamentoid, centrocostoid)
        SELECT p_usuarioid, p_empresaid, LP.lugarpagoid, DP.departamentoid, CC.centrocostoid
        FROM lugarespago AS LP
        INNER JOIN departamentos DP ON LP.lugarpagoid = DP.lugarpagoid AND LP.empresaid = DP.empresaid
        INNER JOIN centroscosto CC ON CC.lugarpagoid = DP.lugarpagoid 
                                    AND CC.empresaid = DP.empresaid 
                                    AND CC.departamentoid = DP.departamentoid
        LEFT JOIN g_accesoxusuarioccosto AS ACC ON ACC.usuarioid = p_usuarioid
                                                  AND ACC.empresaid = p_empresaid
                                                  AND ACC.lugarpagoid = LP.lugarpagoid
                                                  AND ACC.departamentoid = DP.departamentoid
                                                  AND ACC.centrocostoid = CC.centrocostoid
        WHERE ACC.centrocostoid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
        LEFT JOIN g_accesoxusuariodivision AS ACC ON ACC.usuarioid = p_usuarioid
                                                   AND ACC.empresaid = p_empresaid
                                                   AND ACC.lugarpagoid = LP.lugarpagoid
                                                   AND ACC.departamentoid = DP.departamentoid
                                                   AND ACC.centrocostoid = CC.centrocostoid
                                                   AND ACC.divisionid = DIV.divisionid
        WHERE ACC.divisionid IS NULL
        AND LP.empresaid = p_empresaid
        AND LP.lugarpagoid = p_lugarpagoid;
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
        INNER JOIN division DIV ON CC.lugarpagoid = DIV.lugarpagoid 
                                AND CC.empresaid = DIV.empresaid 
                                AND CC.departamentoid = DIV.departamentoid 
                                AND CC.centrocostoid = DIV.centrocostoid
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
        AND LP.lugarpagoid = p_lugarpagoid;
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


-- FUNCTION: public.sp_g_accesoxusuario_elimina_departamento(refcursor, character varying, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_elimina_departamento(refcursor, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_elimina_departamento(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe el registro en departamentos
    IF EXISTS
        (
            SELECT usuarioid FROM g_accesoxusuariodepartamento 
            WHERE usuarioid = p_usuarioid 
            AND empresaid = p_empresaid 
            AND lugarpagoid = p_lugarpagoid 
            AND departamentoid = p_departamentoid
        ) 
    THEN 
        -- Nivel 3: Centro de Costo (desde nivel 3 hacia abajo)
        IF v_niveles >= 3 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM g_accesoxusuarioccosto
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid	
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM g_accesoxusuariodivision
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid
            ) THEN
                DELETE FROM g_accesoxusuarioquintonivel
                WHERE usuarioid = p_usuarioid 
                AND empresaid = p_empresaid
                AND lugarpagoid = p_lugarpagoid
                AND departamentoid = p_departamentoid;
            END IF;
        END IF;
        
        -- Eliminar el registro principal de departamentos
        DELETE FROM g_accesoxusuariodepartamento 
        WHERE usuarioid = p_usuarioid 
        AND empresaid = p_empresaid 
        AND lugarpagoid = p_lugarpagoid 
        AND departamentoid = p_departamentoid;
    END IF;
    
    var_error := 0;
    var_mensaje := '';
            
    OPEN p_refcursor FOR
        SELECT CAST(var_error AS INTEGER) AS error, CAST(var_mensaje AS VARCHAR(100)) AS mensaje;
    
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_elimina_empresa(refcursor, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_elimina_empresa(refcursor, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_elimina_empresa(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor ALIAS FOR p_refcursor;
    var_error  INTEGER := 0;
    var_mensaje TEXT := '';
    v_niveles INTEGER := 0;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    IF EXISTS (
        SELECT 1 FROM g_accesoxusuarioempresas 
        WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
    ) THEN
        -- Nivel 1: Lugares de Pago
        IF v_niveles >= 1 THEN
            IF EXISTS (
                SELECT 1 FROM g_accesoxusuariolugarespago 
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
            ) THEN
                DELETE FROM g_accesoxusuariolugarespago
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;
            END IF;
        END IF;

        -- Nivel 2: Departamentos
        IF v_niveles >= 2 THEN
            IF EXISTS (
                SELECT 1 FROM g_accesoxusuariodepartamento 
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
            ) THEN
                DELETE FROM g_accesoxusuariodepartamento
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;
            END IF;
        END IF;

        -- Nivel 3: Centro de Costo
        IF v_niveles >= 3 THEN
            IF EXISTS (
                SELECT 1 FROM g_accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
            ) THEN
                DELETE FROM g_accesoxusuarioccosto
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;
            END IF;
        END IF;

        -- Nivel 4: División
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT 1 FROM g_accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
            ) THEN
                DELETE FROM g_accesoxusuariodivision
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;
            END IF;
        END IF;

        -- Nivel 5: Quinto Nivel
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT 1 FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid
            ) THEN
                DELETE FROM g_accesoxusuarioquintonivel
                WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;
            END IF;
        END IF;

        DELETE FROM g_accesoxusuarioempresas
        WHERE usuarioid = p_usuarioid AND empresaid = p_empresaid;

        var_error := 0;
        var_mensaje := '';
    END IF;

    OPEN var_cursor FOR
    SELECT var_error AS "error", var_mensaje AS "mensaje";

    RETURN var_cursor;

EXCEPTION WHEN OTHERS THEN
    OPEN var_cursor FOR
    SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN var_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_g_accesoxusuario_elimina_lugarpago(refcursor, character varying, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_g_accesoxusuario_elimina_lugarpago(refcursor, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_g_accesoxusuario_elimina_lugarpago(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_empresaid character varying,
	p_lugarpagoid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    v_niveles INTEGER := 0;
BEGIN
    -- Inicializar variables
    var_error := 0;
    var_mensaje := '';
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar si existe el registro en lugares de pago
    IF EXISTS (
        SELECT usuarioid 
        FROM g_accesoxusuariolugarespago 
        WHERE usuarioid = p_usuarioid 
            AND empresaid = p_empresaid 
            AND lugarpagoid = p_lugarpagoid
    ) THEN
        -- Nivel 2: Departamentos (desde nivel 2 hacia abajo)
        IF v_niveles >= 2 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM g_accesoxusuariodepartamento 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM g_accesoxusuariodepartamento
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 3: Centro de Costo (desde nivel 3 hacia abajo)
        IF v_niveles >= 3 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM g_accesoxusuarioccosto 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM g_accesoxusuarioccosto
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 4: División (desde nivel 4 hacia abajo)
        IF v_niveles >= 4 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM g_accesoxusuariodivision 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM g_accesoxusuariodivision
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Nivel 5: Quinto Nivel (desde nivel 5 hacia abajo)
        IF v_niveles >= 5 THEN
            IF EXISTS (
                SELECT usuarioid 
                FROM g_accesoxusuarioquintonivel 
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid
            ) THEN
                DELETE FROM g_accesoxusuarioquintonivel
                WHERE usuarioid = p_usuarioid 
                    AND empresaid = p_empresaid
                    AND lugarpagoid = p_lugarpagoid;
            END IF;
        END IF;
        
        -- Eliminar el registro principal de lugares de pago
        DELETE FROM g_accesoxusuariolugarespago 
        WHERE usuarioid = p_usuarioid 
            AND empresaid = p_empresaid 
            AND lugarpagoid = p_lugarpagoid;
    END IF;
    
    -- Retornar resultado
    OPEN p_refcursor FOR
        SELECT var_error::INTEGER AS error, var_mensaje AS mensaje;
    
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_gestorpersonas_listaxtipodoc(refcursor, character varying, character varying, integer, integer, integer, numeric)

-- DROP FUNCTION IF EXISTS public.sp_gestorpersonas_listaxtipodoc(refcursor, character varying, character varying, integer, integer, integer, numeric);

-- =============================================
-- Autor: Emanuel Cuello
-- Migrado a PostgreSQL: 15-10-2025
-- Actualizado a Niveles Dinámicos: 15-10-2025
-- Actualización: 29-10-2025 - Corregido uso de EMPL.* en JOINs de niveles
-- Descripción: Consulta tipos de documentos de un empleado con niveles dinámicos
-- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*) para niveles y permisos, no niveles históricos del documento (DOC.*)
-- Ejemplo: SELECT sp_gestorpersonas_listaxtipodoc('cur_lista','11111111-1','22222222-2',1,10,1,9999);
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_gestorpersonas_listaxtipodoc(
	p_refcursor refcursor,
	p_empleadoid character varying,
	p_usuarioid character varying,
	p_tipodocumentoid integer,
	p_tipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor REFCURSOR := p_refcursor;
    var_sql text;
    v_niveles integer;
    v_inicio integer;
    v_fin integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_gestorpersonas_listaxtipodoc - Usuario: ' || COALESCE(p_usuarioid, 'NULL') || 
                       ' - Empleado: ' || COALESCE(p_empleadoid, 'NULL') || 
                       ' - TipoDoc: ' || COALESCE(p_tipodocumentoid::text, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Calcular paginación
    v_inicio := (p_pagina - 1) * p_decuantos + 1;
    v_fin := p_pagina * p_decuantos;
    RAISE NOTICE 'Paginación - Inicio: % - Fin: %', v_inicio, v_fin;

    -- Construcción dinámica de campos SELECT
    var_sql := '
        SELECT
            DOC.documentoid,
            DOC.tipodocumentoid,
            TG.nombre AS nombredocumento,
            DOC.empleadoid,
            COALESCE(PER.nombre, '''') || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''') AS nombre,
            DOC.empresaid,
            EMP.RazonSocial AS nombreempresa';

    -- Agregar campos de niveles dinámicamente (TODOS desde EMPL)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
            EMPL.lugarpagoid,
            LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campos nivel 1: lugarespago';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
            EMPL.departamentoid,
            DP.nombredepartamento';
        RAISE NOTICE 'Agregando campos nivel 2: departamentos';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
            EMPL.centrocostoid,
            CCO.nombrecentrocosto';
        RAISE NOTICE 'Agregando campos nivel 3: centroscosto';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
            EMPL.divisionid,
            DIV.nombredivision';
        RAISE NOTICE 'Agregando campos nivel 4: division';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
            EMPL.quintonivelid,
            QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campos nivel 5: quinto_nivel';
    END IF;

    -- Agregar campos adicionales
    var_sql := var_sql || ',
            TO_CHAR(DOC.fechadocumento, ''DD-MM-YYYY'') AS fechadocumento,
            TO_CHAR(DOC.fechacreacion, ''DD-MM-YYYY'') AS fechacreacion,
            TO_CHAR(DOC.fechatermino, ''DD-MM-YYYY'') AS fechatermino,
            COALESCE(DOC.NumeroContrato, 0) AS nrocontrato,
            ROW_NUMBER() OVER (ORDER BY DOC.fechadocumento) AS rownum';

    -- FROM y JOINs base
    var_sql := var_sql || '
        FROM g_documentosinfo AS DOC
        INNER JOIN g_tiposdocumentosxperfil
            ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
           AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
        INNER JOIN empleados AS EMPL
            ON EMPL.empleadoid = DOC.empleadoid
           AND EMPL.RutEmpresa = DOC.empresaid
        INNER JOIN TipoGestor AS TG
            ON TG.idTipoGestor = DOC.tipodocumentoid
        INNER JOIN personas AS PER
            ON PER.personaid = EMPL.empleadoid
        INNER JOIN empresas AS EMP
            ON EMP.RutEmpresa = DOC.empresaid';

    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        INNER JOIN lugarespago AS LP
            ON LP.lugarpagoid = EMPL.lugarpagoid
           AND LP.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        INNER JOIN departamentos AS DP
            ON DP.departamentoid = EMPL.departamentoid
           AND DP.lugarpagoid = EMPL.lugarpagoid
           AND DP.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        INNER JOIN centroscosto AS CCO
            ON CCO.centrocostoid = EMPL.centrocostoid
           AND CCO.lugarpagoid = EMPL.lugarpagoid
           AND CCO.departamentoid = EMPL.departamentoid
           AND CCO.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        INNER JOIN division AS DIV
            ON DIV.divisionid = EMPL.divisionid
           AND DIV.lugarpagoid = EMPL.lugarpagoid
           AND DIV.departamentoid = EMPL.departamentoid
           AND DIV.centrocostoid = EMPL.centrocostoid
           AND DIV.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN quinto_nivel AS QN
            ON QN.quintonivelid = EMPL.quintonivelid
           AND QN.lugarpagoid = EMPL.lugarpagoid
           AND QN.departamentoid = EMPL.departamentoid
           AND QN.centrocostoid = EMPL.centrocostoid
           AND QN.divisionid = EMPL.divisionid
           AND QN.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
    END IF;

    -- Aplicar permisos según el nivel más alto disponible (usando EMPL.*, no DOC.*)
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariolugarespago ALP
            ON ALP.empresaid = EMPL.RutEmpresa
           AND ALP.lugarpagoid = EMPL.lugarpagoid
           AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: g_accesoxusuariolugarespago (desde EMPL)';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodepartamento ACC
            ON ACC.empresaid = EMPL.RutEmpresa
           AND ACC.lugarpagoid = EMPL.lugarpagoid
           AND ACC.departamentoid = EMPL.departamentoid
           AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: g_accesoxusuariodepartamento (desde EMPL)';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioccosto ACC
            ON ACC.empresaid = EMPL.RutEmpresa
           AND ACC.lugarpagoid = EMPL.lugarpagoid
           AND ACC.departamentoid = EMPL.departamentoid
           AND ACC.centrocostoid = EMPL.centrocostoid
           AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: g_accesoxusuarioccosto (desde EMPL)';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodivision ADIV
            ON ADIV.empresaid = EMPL.RutEmpresa
           AND ADIV.lugarpagoid = EMPL.lugarpagoid
           AND ADIV.departamentoid = EMPL.departamentoid
           AND ADIV.centrocostoid = EMPL.centrocostoid
           AND ADIV.divisionid = EMPL.divisionid
           AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: g_accesoxusuariodivision (desde EMPL)';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioquintonivel AQN
            ON AQN.empresaid = EMPL.RutEmpresa
           AND AQN.lugarpagoid = EMPL.lugarpagoid
           AND AQN.departamentoid = EMPL.departamentoid
           AND AQN.centrocostoid = EMPL.centrocostoid
           AND AQN.divisionid = EMPL.divisionid
           AND AQN.quintonivelid = EMPL.quintonivelid
           AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: g_accesoxusuarioquintonivel (desde EMPL)';
    END IF;

    -- Condiciones WHERE
    var_sql := var_sql || '
        WHERE EMPL.empleadoid = ' || quote_literal(p_empleadoid) || '
          AND DOC.tipodocumentoid = ' || p_tipodocumentoid;

    -- Log de la consulta SQL final (primeros 1000 caracteres)
    RAISE NOTICE 'Consulta SQL final construida (primeros 1000 caracteres): %', LEFT(var_sql, 1000);

    -- Agregar paginación
    var_sql := 'SELECT * FROM (' || var_sql || ') AS ResultadoPaginado
               WHERE rownum BETWEEN ' || v_inicio || ' AND ' || v_fin;

    RAISE NOTICE 'Ejecutando consulta de listado con paginación';

    -- Abrir cursor con los resultados
    OPEN var_cursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_gestorpersonas_listaxtipodoc: %', SQLERRM;
        OPEN var_cursor FOR
        SELECT 'Error en sp_gestorpersonas_listaxtipodoc: ' || SQLERRM AS mensaje;
        RETURN p_refcursor;
END;
$BODY$;


-- =============================================
-- Autor: Cristian Soto
-- Creado el: 7/11/2016
-- Modificado: 21-08-2017 RC
-- Migrado a PostgreSQL: 15-10-2025
-- Autor: Emanuel Cuello
-- Actualizado a Niveles Dinámicos: 15-10-2025
-- Actualización: 29-10-2025 - Corregido uso de EMPL.* en JOINs de niveles
-- Descripcion: Consulta el total de tipos de documentos a mostrar según consulta
-- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*) para niveles y permisos, no niveles históricos del documento (DOC.*)
-- Ejemplo: SELECT sp_gestorpersonas_listaxtipodoc_total('cur_total','11111111-1','22222222-2',1,10,9999);
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_gestorpersonas_listaxtipodoc_total(
    p_refcursor refcursor,                   -- cursor de retorno
    p_empleadoid character varying(10),      -- id del empleado
    p_usuarioid character varying(10),       -- id del usuario
    p_tipodocumentoid integer,               -- id del tipo de documento
    p_tipousuarioid integer,                 -- id del tipo de usuario o perfil
    p_decuantos numeric                      -- cantidad de filas a mostrar en la pagina
)
RETURNS refcursor
LANGUAGE 'plpgsql'
COST 100
VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    -- Cursor para retornar resultados
    var_cursor REFCURSOR := p_refcursor;
    
    -- Variables de consulta SQL
    var_sql TEXT;
    
    -- Variables de niveles
    v_niveles integer;
    
    -- Variables de cálculo y totales
    var_totalreg NUMERIC;
    var_vdecimal NUMERIC(9,5);
    var_total INTEGER;
    
    -- Variables para logging
    var_log_message text;
    var_xnomtipodoc VARCHAR(100);
    
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_gestorpersonas_listaxtipodoc_total - Usuario: ' || COALESCE(p_usuarioid, 'NULL') || 
                       ' - Empleado: ' || COALESCE(p_empleadoid, 'NULL') || 
                       ' - TipoDoc: ' || COALESCE(p_tipodocumentoid::text, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Obtener nombre del tipo de documento
    SELECT nombre INTO var_xnomtipodoc 
    FROM TipoGestor 
    WHERE idTipoGestor = p_tipodocumentoid;
    RAISE NOTICE 'Tipo de documento: %', var_xnomtipodoc;
    
    -- Construir consulta base para contar registros
    var_sql := '
        SELECT COUNT(DISTINCT DOC.documentoid) as total_registros
        FROM g_documentosinfo AS DOC
        INNER JOIN g_tiposdocumentosxperfil 
            ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid 
            AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
        INNER JOIN empleados AS EMPL 
            ON EMPL.empleadoid = DOC.empleadoid 
            AND EMPL.RutEmpresa = DOC.empresaid
        INNER JOIN TipoGestor AS TG 
            ON TG.idTipoGestor = DOC.tipodocumentoid
        INNER JOIN personas AS PER 
            ON PER.personaid = EMPL.empleadoid
        INNER JOIN empresas AS EMP 
            ON EMP.RutEmpresa = DOC.empresaid';

    -- JOINs de niveles dinámicos (TODOS usando EMPL.*, no DOC.*)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        INNER JOIN lugarespago AS LP 
            ON LP.lugarpagoid = EMPL.lugarpagoid 
            AND LP.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago (desde EMPL)';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        INNER JOIN departamentos AS DP 
            ON DP.departamentoid = EMPL.departamentoid 
            AND DP.lugarpagoid = EMPL.lugarpagoid 
            AND DP.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos (desde EMPL)';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        INNER JOIN centroscosto AS CC 
            ON CC.centrocostoid = EMPL.centrocostoid 
            AND CC.departamentoid = EMPL.departamentoid 
            AND CC.lugarpagoid = EMPL.lugarpagoid 
            AND CC.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto (desde EMPL)';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        INNER JOIN division AS DV 
            ON DV.centrocostoid = EMPL.centrocostoid 
            AND DV.lugarpagoid = EMPL.lugarpagoid 
            AND DV.empresaid = EMPL.RutEmpresa 
            AND DV.departamentoid = EMPL.departamentoid 
            AND DV.divisionid = EMPL.divisionid';
        RAISE NOTICE 'Agregando JOIN nivel 4: division (desde EMPL)';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN quinto_nivel AS QN 
            ON QN.quintonivelid = EMPL.quintonivelid 
            AND QN.lugarpagoid = EMPL.lugarpagoid 
            AND QN.departamentoid = EMPL.departamentoid 
            AND QN.centrocostoid = EMPL.centrocostoid 
            AND QN.divisionid = EMPL.divisionid 
            AND QN.empresaid = EMPL.RutEmpresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel (desde EMPL)';
    END IF;

    -- Aplicar permisos según el nivel más alto disponible (usando EMPL.*, no DOC.*)
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariolugarespago ALP 
            ON ALP.usuarioid = ' || quote_literal(p_usuarioid) || '
            AND ALP.empresaid = EMPL.RutEmpresa 
            AND ALP.lugarpagoid = EMPL.lugarpagoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: g_accesoxusuariolugarespago (desde EMPL)';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodepartamento ADV 
            ON ADV.usuarioid = ' || quote_literal(p_usuarioid) || '
            AND ADV.empresaid = EMPL.RutEmpresa 
            AND ADV.lugarpagoid = EMPL.lugarpagoid 
            AND ADV.departamentoid = EMPL.departamentoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: g_accesoxusuariodepartamento (desde EMPL)';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioccosto ACC 
            ON ACC.usuarioid = ' || quote_literal(p_usuarioid) || '
            AND ACC.empresaid = EMPL.RutEmpresa 
            AND ACC.lugarpagoid = EMPL.lugarpagoid 
            AND ACC.departamentoid = EMPL.departamentoid 
            AND ACC.centrocostoid = EMPL.centrocostoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: g_accesoxusuarioccosto (desde EMPL)';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodivision ADV 
            ON ADV.usuarioid = ' || quote_literal(p_usuarioid) || '
            AND ADV.empresaid = EMPL.RutEmpresa 
            AND ADV.lugarpagoid = EMPL.lugarpagoid 
            AND ADV.centrocostoid = EMPL.centrocostoid 
            AND ADV.departamentoid = EMPL.departamentoid 
            AND ADV.divisionid = EMPL.divisionid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: g_accesoxusuariodivision (desde EMPL)';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioquintonivel AQN 
            ON AQN.usuarioid = ' || quote_literal(p_usuarioid) || '
            AND AQN.empresaid = EMPL.RutEmpresa 
            AND AQN.lugarpagoid = EMPL.lugarpagoid 
            AND AQN.departamentoid = EMPL.departamentoid 
            AND AQN.centrocostoid = EMPL.centrocostoid 
            AND AQN.divisionid = EMPL.divisionid 
            AND AQN.quintonivelid = EMPL.quintonivelid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: g_accesoxusuarioquintonivel (desde EMPL)';
    END IF;

    -- Condiciones WHERE (deben ser idénticas al SP de listado)
    var_sql := var_sql || '
        WHERE EMPL.empleadoid = ' || quote_literal(p_empleadoid) || '
        AND DOC.tipodocumentoid = ' || p_tipodocumentoid;

    -- Log de la consulta SQL final (primeros 1000 caracteres)
    RAISE NOTICE 'Consulta SQL final construida (primeros 1000 caracteres): %', LEFT(var_sql, 1000);
    
    -- Ejecutar consulta de conteo
    EXECUTE var_sql INTO var_totalreg;
    
    -- Si no se encontró var_totalreg, asignar 0
    IF var_totalreg IS NULL THEN
        var_totalreg := 0;
    END IF;
    
    RAISE NOTICE 'Total de registros encontrados: %', var_totalreg;
    
    -- Calcular total de páginas
    IF p_decuantos > 0 THEN
        var_vdecimal := var_totalreg / p_decuantos;
        var_total := CEIL(var_vdecimal);
    ELSE
        var_total := 0;
    END IF;
    
    RAISE NOTICE 'Total de páginas: %', var_total;
    
    -- Abrir cursor con el resultado
    OPEN var_cursor FOR 
        SELECT var_total AS "total", var_totalreg AS "totalreg";
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_gestorpersonas_listaxtipodoc_total: %', SQLERRM;
        OPEN var_cursor FOR
        SELECT 'Error en sp_gestorpersonas_listaxtipodoc_total: ' || SQLERRM AS "mensaje";
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_gestorpersonas_xrut(refcursor, character varying, character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_gestorpersonas_xrut(refcursor, character varying, character varying, integer, integer);

-- =============================================
-- Autor: Emanuel Cuello
-- Actualizado a Niveles Dinámicos: 15-10-2025
-- Descripción: Consulta tipos de documentos de un empleado con permisos dinámicos
-- IMPORTANTE: Usa niveles actuales del empleado (EMPL.*), no niveles históricos del documento (DOC.*)
-- Ejemplo: SELECT sp_gestorpersonas_xrut('cur_xrut','11111111-1','22222222-2',10,0);
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_gestorpersonas_xrut(
	p_refcursor refcursor,
	p_empleadoid character varying,
	p_usuarioid character varying,
	p_tipousuarioid integer,
	p_agrupadorid integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor        REFCURSOR := p_refcursor;
    var_rolid         INTEGER;
    var_estado        VARCHAR(1);
    var_rolempleado   INTEGER;
    var_estadoempleado VARCHAR(1);
    v_niveles         INTEGER;
    var_sql           TEXT;
    var_log_message   TEXT;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_gestorpersonas_xrut - Usuario: ' || COALESCE(p_usuarioid, 'NULL') || 
                       ' - Empleado: ' || COALESCE(p_empleadoid, 'NULL') || 
                       ' - Agrupador: ' || COALESCE(p_agrupadorid::text, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- Obtener rol y estado del usuario
    SELECT COALESCE(rolid, 2), COALESCE(idEstadoEmpleado, 'A')
      INTO var_rolid, var_estado
    FROM usuarios
    WHERE usuarioid = p_usuarioid;

    RAISE NOTICE 'Usuario - Rol: % - Estado: %', var_rolid, var_estado;

    -- Obtener rol y estado del empleado
    SELECT rolid, idEstadoEmpleado
      INTO var_rolempleado, var_estadoempleado
    FROM empleados
    WHERE empleadoid = p_empleadoid;

    RAISE NOTICE 'Empleado - Rol: % - Estado: %', var_rolempleado, var_estadoempleado;

    -- Validaciones
    IF (var_rolid = 2 AND var_rolempleado = 1) THEN
        RAISE NOTICE 'Acceso denegado: rol privado';
        OPEN var_cursor FOR
        SELECT 'No autorizado: rol privado' AS "mensaje";
        RETURN p_refcursor;
    END IF;

    IF (var_estado = 'A' AND var_estadoempleado <> 'A') THEN
        RAISE NOTICE 'Acceso denegado: empleado finiquitado';
        OPEN var_cursor FOR
        SELECT 'No autorizado: empleado finiquitado' AS "mensaje";
        RETURN p_refcursor;
    END IF;

    -- Construir consulta dinámica base
    var_sql := '
        SELECT 
            ' || quote_literal(p_empleadoid) || ' AS empleadoid,
            TipoGestor.idTipoGestor AS tipodocumentoid,
            TipoGestor.nombre AS nombre,
            ' || p_agrupadorid || ' AS agrupadorid
        FROM g_documentosinfo AS DOC
        INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
        INNER JOIN TipoGestor ON TipoGestor.idTipoGestor = DOC.tipodocumentoid
        INNER JOIN g_tiposdocumentosxperfil 
            ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
           AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid;

    -- Aplicar permisos según el nivel más alto disponible (usando EMPL.*, no DOC.*)
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariolugarespago ALP
            ON ALP.usuarioid = ' || quote_literal(p_usuarioid) || '
           AND ALP.empresaid = EMPL.RutEmpresa
           AND ALP.lugarpagoid = EMPL.lugarpagoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: g_accesoxusuariolugarespago (desde EMPL)';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodepartamento ADV
            ON ADV.usuarioid = ' || quote_literal(p_usuarioid) || '
           AND ADV.empresaid = EMPL.RutEmpresa
           AND ADV.lugarpagoid = EMPL.lugarpagoid
           AND ADV.departamentoid = EMPL.departamentoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: g_accesoxusuariodepartamento (desde EMPL)';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioccosto ACC
            ON ACC.usuarioid = ' || quote_literal(p_usuarioid) || '
           AND ACC.empresaid = EMPL.RutEmpresa
           AND ACC.lugarpagoid = EMPL.lugarpagoid
           AND ACC.departamentoid = EMPL.departamentoid
           AND ACC.centrocostoid = EMPL.centrocostoid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: g_accesoxusuarioccosto (desde EMPL)';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodivision ADIV
            ON ADIV.usuarioid = ' || quote_literal(p_usuarioid) || '
           AND ADIV.empresaid = EMPL.RutEmpresa
           AND ADIV.lugarpagoid = EMPL.lugarpagoid
           AND ADIV.departamentoid = EMPL.departamentoid
           AND ADIV.centrocostoid = EMPL.centrocostoid
           AND ADIV.divisionid = EMPL.divisionid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: g_accesoxusuariodivision (desde EMPL)';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioquintonivel AQN
            ON AQN.usuarioid = ' || quote_literal(p_usuarioid) || '
           AND AQN.empresaid = EMPL.RutEmpresa
           AND AQN.lugarpagoid = EMPL.lugarpagoid
           AND AQN.departamentoid = EMPL.departamentoid
           AND AQN.centrocostoid = EMPL.centrocostoid
           AND AQN.divisionid = EMPL.divisionid
           AND AQN.quintonivelid = EMPL.quintonivelid';
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: g_accesoxusuarioquintonivel (desde EMPL)';
    END IF;

    -- Agregar condición de agrupador si corresponde
    IF p_agrupadorid != 0 THEN
        var_sql := var_sql || '
        INNER JOIN agrupadortiposdocumentos_tipos AS agtp 
            ON agtp.tipodocumentoid = DOC.tipodocumentoid
           AND agtp.agrupadorid = ' || p_agrupadorid;
        RAISE NOTICE 'Agregando filtro de agrupador: %', p_agrupadorid;
    END IF;

    -- Agregar WHERE y GROUP BY
    var_sql := var_sql || '
        WHERE DOC.empleadoid = ' || quote_literal(p_empleadoid) || '
        GROUP BY TipoGestor.idTipoGestor, TipoGestor.nombre';

    -- Log de la consulta SQL final (primeros 1000 caracteres)
    RAISE NOTICE 'Consulta SQL final construida (primeros 1000 caracteres): %', LEFT(var_sql, 1000);

    -- Ejecutar consulta dinámica
    RAISE NOTICE 'Ejecutando consulta dinámica';
    OPEN var_cursor FOR EXECUTE var_sql;

    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_gestorpersonas_xrut: %', SQLERRM;
        OPEN var_cursor FOR
        SELECT 'Error en sp_gestorpersonas_xrut: ' || SQLERRM AS "mensaje";
        RETURN p_refcursor;
END;
$BODY$;
-- FUNCTION: public.sp_importacion_firma(refcursor, character varying, character varying, integer, integer, integer, character varying, character varying, integer, character varying, character varying, integer, integer, date, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_importacion_firma(refcursor, character varying, character varying, integer, integer, integer, character varying, character varying, integer, character varying, character varying, integer, integer, date, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_importacion_firma(
	p_refcursor refcursor,
	p_paccion character varying,
	p_pusuarioid character varying,
	p_ppagina integer,
	p_ppaginainicio integer,
	p_ppaginafin integer,
	p_pempleadoid character varying,
	p_pempresaid character varying,
	p_pestado integer,
	p_pobservacion character varying,
	p_prutrepresentantes character varying,
	p_ptipodocumentoid integer,
	p_pprocesofirma integer,
	p_pfechadocumento date,
	p_ptotalpaginas integer,
	p_preprocesado integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error      integer;
    v_mensaje    varchar(100);
    v_basegestor varchar(50);
    v_sqlstring  text;
BEGIN
    -- Valor de basegestor (si lo necesitas)
    SELECT parametro INTO v_basegestor
      FROM parametros
     WHERE idparametro = 'gestor';

    IF p_pAccion = 'Grabar' THEN
        IF NOT EXISTS (
            SELECT 1
              FROM importacion_firma
             WHERE usuarioid = p_pusuarioid
               AND pagina    = p_ppagina
        ) THEN
            INSERT INTO importacion_firma(
                usuarioid, pagina, paginainicio, paginafin,
                empleadoid, empresaid, estado, observacion,
                rutrepresentantes, tipocontrato, procesofirma,
                fechadocumento, totalpaginas
            ) VALUES (
                p_pusuarioid, p_ppagina, p_ppaginainicio, p_ppaginafin,
                p_pempleadoid, p_pempresaid, p_pestado, p_pobservacion,
                p_prutrepresentantes, p_ptipodocumentoid, p_pprocesofirma,
                p_pfechadocumento, p_ptotalpaginas
            );
        ELSE
            UPDATE importacion_firma
               SET empleadoid        = p_pempleadoid,
                   empresaid         = p_pempresaid,
                   estado            = p_pestado,
                   observacion       = p_pobservacion,
                   tipocontrato      = p_ptipodocumentoid,
                   procesofirma      = p_pprocesofirma,
                   fechadocumento    = p_pfechadocumento,
                   reprocesado       = p_preprocesado
             WHERE usuarioid = p_pusuarioid
               AND pagina    = p_ppagina;
        END IF;
        v_error   := 0;
        v_mensaje := '';

        OPEN p_refcursor FOR
          SELECT v_error AS error, v_mensaje AS mensaje;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'Listado' THEN
        v_sqlstring := format($f$
            SELECT
                imp.usuarioid,
                imp.usuarioid,
                imp.pagina,
                imp.paginainicio,
                imp.paginafin,
                imp.empleadoid,
                COALESCE(per.nombre,'') || ' ' ||
                COALESCE(per.appaterno,'') || ' ' ||
                COALESCE(per.apmaterno,'') AS nombre,
                CASE imp.estado WHEN 0 THEN 'No enviado' WHEN 1 THEN 'Enviado' END AS estado,
                imp.observacion,
                CASE imp.estado WHEN 0 THEN 'checked' ELSE '' END      AS checked_sn,
                CASE imp.estado WHEN 0 THEN '' WHEN 1 THEN 'disabled' END AS disabled
            FROM importacion_firma imp
            LEFT JOIN empleados empl ON imp.empleadoid = empl.empleadoid
            LEFT JOIN personas per   ON empl.empleadoid = per.personaid
            WHERE imp.usuarioid = %L
            ORDER BY imp.pagina
        $f$, p_pusuarioid);
        OPEN p_refcursor FOR EXECUTE v_sqlstring;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerEmpleado' THEN
        v_sqlstring := format($f$
            SELECT
                empl.empleadoid,
                per.nombre,
                per.appaterno,
                per.apmaterno,
                empl.centrocostoid,
                empl.lugarpagoid,
                empl.departamentoid,
                empl.centrocostoid,
                empl.divisionid,
                empl.quintonivelid,
                empl.rutempresa,
                to_char(per.fechanacimiento,'DD/MM/YYYY') AS fechanacimiento,
                per.correo,
                per.nacionalidad,
                per.estadocivil,
                per.estadocivil AS idestadocivil,
                per.direccion,
                per.comuna,
                per.ciudad
            FROM personas per
            INNER JOIN empleados empl ON empl.empleadoid = per.personaid
            WHERE per.personaid = %L
        $f$, p_pempleadoid);
        OPEN p_refcursor FOR EXECUTE v_sqlstring;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'Eliminar' THEN
        DELETE FROM importacion_firma
         WHERE usuarioid = p_pusuarioid;

        v_error   := 0;
        v_mensaje := '';
        OPEN p_refcursor FOR
          SELECT v_error AS error, v_mensaje AS mensaje;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerProceso' THEN
        OPEN p_refcursor FOR
          SELECT
            empresaid,
            rutrepresentantes,
            tipocontrato,
            procesofirma,
            to_char(fechadocumento,'DD/MM/YYYY') AS fechadocumento,
            procesofirma,
            totalpaginas
          FROM importacion_firma
         WHERE usuarioid = p_pusuarioid
         ORDER BY pagina
         LIMIT 1;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerPagina' THEN
        OPEN p_refcursor FOR
          SELECT
            pagina,
            empresaid,
            rutrepresentantes,
            tipocontrato,
            to_char(fechadocumento,'DD/MM/YYYY') AS fechadocumento,
            procesofirma,
            empleadoid,
            totalpaginas
          FROM importacion_firma
         WHERE usuarioid = p_pusuarioid
           AND pagina    = p_ppagina;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'GrabarEstado' THEN
        UPDATE importacion_firma
           SET estado      = p_pestado,
               observacion = p_pobservacion
         WHERE usuarioid = p_pusuarioid
           AND pagina    = p_ppagina;
        v_error   := 0;
        v_mensaje := '';
        OPEN p_refcursor FOR
          SELECT v_error AS error, v_mensaje AS mensaje;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerUltimaPagina' THEN
        OPEN p_refcursor FOR
          SELECT
            usuarioid, pagina, paginainicio, paginafin,
            empleadoid, empresaid, rutrepresentantes,
            tipocontrato, procesofirma,
            to_char(fechadocumento,'DD/MM/YYYY') AS fechadocumento,
            procesofirma, empleadoid, totalpaginas
          FROM importacion_firma
         WHERE usuarioid = p_pusuarioid
         ORDER BY pagina DESC
         LIMIT 1;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerConfiguracion' THEN
        OPEN p_refcursor FOR
          SELECT
            tipo,
            paginasxdocumento,
            rutadescartar,
            frasevalidacion
          FROM importacion_firma_configuracion
         WHERE tipo = p_ptipodocumentoid;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'DesmarcarReproceso' THEN
        UPDATE importacion_firma
           SET reprocesado = 0
         WHERE usuarioid = p_pusuarioid;
        v_error   := 0;
        v_mensaje := '';
        OPEN p_refcursor FOR
          SELECT v_error AS error, v_mensaje AS mensaje;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerNoEnviado' THEN
        OPEN p_refcursor FOR
          SELECT
            pagina, empresaid, rutrepresentantes,
            tipocontrato, to_char(fechadocumento,'DD/MM/YYYY') AS fechadocumento,
            procesofirma, empleadoid, totalpaginas
          FROM importacion_firma
         WHERE usuarioid = p_pusuarioid
           AND estado    = 0
           AND pagina   > p_ppagina
         ORDER BY pagina;
        RETURN p_refcursor;

    ELSIF p_pAccion = 'ObtenerReprocesados' THEN
        OPEN p_refcursor FOR
          SELECT COUNT(*) AS reprocesados
            FROM importacion_firma
           WHERE usuarioid   = p_pusuarioid
             AND reprocesado = 1;
        RETURN p_refcursor;

    ELSE
        v_error   := -1;
        v_mensaje := 'Acción inválida';
        OPEN p_refcursor FOR
          SELECT v_error AS error, v_mensaje AS mensaje;
        RETURN p_refcursor;
    END IF;
END;
$BODY$;


-- FUNCTION: public.sp_importacionagestor(refcursor, character, character varying, integer, character varying, date, date, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_importacionagestor(refcursor, character, character varying, integer, character varying, date, date, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_importacionagestor(
	p_refcursor refcursor,
	p_accion character,
	p_usuarioid character varying,
	p_tipodocumentoid integer,
	p_empleadoid character varying,
	p_fechadocumento date,
	p_fechatermino date,
	p_ids3 character varying,
	p_nombrearchivo character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error           INTEGER;
    v_mensaje         VARCHAR(100);
    v_estado          INTEGER;
    v_empresaid       VARCHAR(14);
    v_lugarpagoid     VARCHAR(14);
    v_departamentoid  VARCHAR(14);
    v_centrocostoid   VARCHAR(10);
    v_divisionid      VARCHAR(14);
    v_quintonivelid   VARCHAR(14);
    v_documentoid     NUMERIC(18);
    v_niveles         INTEGER;
    v_select_sql      TEXT;
    v_insert_sql      TEXT;
    v_values_sql      TEXT;
BEGIN
    -- Inicializar variables de control
    v_error := 0;
    v_mensaje := '';
    
    -- Log de inicio
    RAISE NOTICE 'INICIO sp_importacionagestor - Usuario: %, Empleado: %', p_usuarioid, p_empleadoid;
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Verificar si el empleado existe
    IF EXISTS(SELECT empleadoid FROM empleados WHERE empleadoid = p_empleadoid) THEN
        
        -- Construir SELECT dinámico según niveles disponibles
        v_select_sql := 'SELECT RutEmpresa';
        
        -- Agregar campos según niveles disponibles
        IF v_niveles >= 1 THEN
            v_select_sql := v_select_sql || ', lugarpagoid';
            RAISE NOTICE 'Agregando campo nivel 1: lugarpagoid';
        END IF;
        
        IF v_niveles >= 2 THEN
            v_select_sql := v_select_sql || ', departamentoid';
            RAISE NOTICE 'Agregando campo nivel 2: departamentoid';
        END IF;
        
        IF v_niveles >= 3 THEN
            v_select_sql := v_select_sql || ', centrocostoid';
            RAISE NOTICE 'Agregando campo nivel 3: centrocostoid';
        END IF;
        
        IF v_niveles >= 4 THEN
            v_select_sql := v_select_sql || ', divisionid';
            RAISE NOTICE 'Agregando campo nivel 4: divisionid';
        END IF;
        
        IF v_niveles = 5 THEN
            v_select_sql := v_select_sql || ', quintonivelid';
            RAISE NOTICE 'Agregando campo nivel 5: quintonivelid';
        END IF;
        
        v_select_sql := v_select_sql || ' FROM empleados WHERE empleadoid = $1';
        
        RAISE NOTICE 'SELECT SQL construido: %', v_select_sql;
        
        -- Obtener datos del empleado según niveles disponibles
        EXECUTE v_select_sql 
        INTO v_empresaid, v_lugarpagoid, v_departamentoid, v_centrocostoid, v_divisionid, v_quintonivelid
        USING p_empleadoid;
        
        -- Construir INSERT dinámico según niveles disponibles
        v_insert_sql := 'INSERT INTO g_documentosinfo (
            tipodocumentoid,
            empleadoid,
            empresaid';
        
        v_values_sql := ' VALUES ($1, $2, $3';
        
        -- Agregar campos de niveles según disponibilidad
        IF v_niveles >= 1 THEN
            v_insert_sql := v_insert_sql || ', lugarpagoid1';
            v_values_sql := v_values_sql || ', $4';
            RAISE NOTICE 'Agregando campo INSERT nivel 1: lugarpagoid1 = %', v_lugarpagoid;
        END IF;
        
        IF v_niveles >= 2 THEN
            v_insert_sql := v_insert_sql || ', departamentoid';
            v_values_sql := v_values_sql || ', $5';
            RAISE NOTICE 'Agregando campo INSERT nivel 2: departamentoid = %', v_departamentoid;
        END IF;
        
        IF v_niveles >= 3 THEN
            v_insert_sql := v_insert_sql || ', centrocostoid';
            v_values_sql := v_values_sql || ', $6';
            RAISE NOTICE 'Agregando campo INSERT nivel 3: centrocostoid = %', v_centrocostoid;
        END IF;
        
        IF v_niveles >= 4 THEN
            v_insert_sql := v_insert_sql || ', divisionid';
            v_values_sql := v_values_sql || ', $7';
            RAISE NOTICE 'Agregando campo INSERT nivel 4: divisionid = %', v_divisionid;
        END IF;
        
        IF v_niveles = 5 THEN
            v_insert_sql := v_insert_sql || ', quintonivelid';
            v_values_sql := v_values_sql || ', $8';
            RAISE NOTICE 'Agregando campo INSERT nivel 5: quintonivelid = %', v_quintonivelid;
        END IF;
        
        -- Agregar campos fijos
        v_insert_sql := v_insert_sql || ',
            fechadocumento,
            fechacreacion,
            Origen,
            usuarioid,
            fechatermino,
            ids3,
            NombreArchivo
        )';
        
        v_values_sql := v_values_sql || ', $9, $10, $11, $12, $13, $14, $15)';
        
        -- Construir SQL completo
        v_insert_sql := v_insert_sql || v_values_sql;
        
        RAISE NOTICE 'INSERT SQL construido: %', v_insert_sql;
        
        -- Ejecutar INSERT dinámico
        EXECUTE v_insert_sql
        USING 
            p_tipodocumentoid,           -- $1
            p_empleadoid,                -- $2
            v_empresaid,                 -- $3
            v_lugarpagoid,               -- $4
            v_departamentoid,            -- $5
            v_centrocostoid,             -- $6
            v_divisionid,                -- $7
            v_quintonivelid,             -- $8
            p_fechadocumento,            -- $9
            CURRENT_TIMESTAMP,           -- $10
            1,                           -- $11 (Origen)
            p_usuarioid,                 -- $12
            p_fechatermino,              -- $13
            p_ids3,                      -- $14
            p_nombrearchivo;             -- $15
        
        -- Obtener el ID del documento insertado
        v_documentoid := LASTVAL();
        
        v_error := 0;
        v_mensaje := '';
        
        RAISE NOTICE 'Documento insertado exitosamente. ID: %', v_documentoid;
    ELSE
        v_error := 1;
        v_mensaje := 'Trabajador no existe';
        RAISE NOTICE 'ERROR: Trabajador no existe - %', p_empleadoid;
    END IF;
    
    -- Retornar resultado a través del cursor
    OPEN p_refcursor FOR
        SELECT v_error, v_mensaje;
    
    RETURN p_refcursor;
    
EXCEPTION
    WHEN OTHERS THEN
        v_error := SQLSTATE;
        v_mensaje := SQLERRM;
        OPEN p_refcursor FOR
            SELECT v_error::INTEGER, v_mensaje;
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_importacionagestormasivo(refcursor, character, character varying, integer, character varying, date, date, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_importacionagestormasivo(refcursor, character, character varying, integer, character varying, date, date, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_importacionagestormasivo(
	p_refcursor refcursor,
	p_paccion character,
	p_pusuarioid character varying,
	p_ptipodocumentoid integer,
	p_pempleadoid character varying,
	p_pfechadocumento date,
	p_pfechatermino date,
	p_pnombrearchivo character varying,
	p_pids3 character varying,
	p_pagrupadorid integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error           INTEGER := 0;
    v_mensaje         VARCHAR(500) := '';
    v_pempresaid      VARCHAR(11);
    v_pdepartamentoid VARCHAR(14);
    v_plugarpagoid    VARCHAR(14);
    v_pcentrocosto    VARCHAR(10);
    v_pdivisionid     VARCHAR(14);
    v_pquintonivelid  VARCHAR(14);
    v_niveles         INTEGER;
    v_select_sql      TEXT;
    v_insert_sql      TEXT;
    v_values_sql      TEXT;
BEGIN
    -- Log de inicio
    RAISE NOTICE 'INICIO sp_importacionagestormasivo - Usuario: %, Empleado: %', p_pusuarioid, p_pempleadoid;
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Construir SELECT dinámico según niveles disponibles
    v_select_sql := 'SELECT rutempresa';
    
    -- Agregar campos según niveles disponibles
    IF v_niveles >= 1 THEN
        v_select_sql := v_select_sql || ', lugarpagoid';
        RAISE NOTICE 'Agregando campo nivel 1: lugarpagoid';
    END IF;
    
    IF v_niveles >= 2 THEN
        v_select_sql := v_select_sql || ', departamentoid';
        RAISE NOTICE 'Agregando campo nivel 2: departamentoid';
    END IF;
    
    IF v_niveles >= 3 THEN
        v_select_sql := v_select_sql || ', centrocostoid';
        RAISE NOTICE 'Agregando campo nivel 3: centrocostoid';
    END IF;
    
    IF v_niveles >= 4 THEN
        v_select_sql := v_select_sql || ', divisionid';
        RAISE NOTICE 'Agregando campo nivel 4: divisionid';
    END IF;
    
    IF v_niveles = 5 THEN
        v_select_sql := v_select_sql || ', quintonivelid';
        RAISE NOTICE 'Agregando campo nivel 5: quintonivelid';
    END IF;
    
    v_select_sql := v_select_sql || ' FROM empleados WHERE empleadoid = $1';
    
    RAISE NOTICE 'SELECT SQL construido: %', v_select_sql;
    
    -- Obtener datos del empleado según niveles disponibles
    EXECUTE v_select_sql 
    INTO v_pempresaid, v_plugarpagoid, v_pdepartamentoid, v_pcentrocosto, v_pdivisionid, v_pquintonivelid
    USING p_pempleadoid;

    -- Intentar inserción dinámica
    BEGIN
        -- Construir INSERT dinámico según niveles disponibles
        v_insert_sql := 'INSERT INTO documentosindexar(
            tipodocumentoid, empleadoid, fechadocumento,
            fechacreacion, usuarioid, indexado,
            nombrearchivo, documentoid,
            empresaid';
        
        v_values_sql := ' VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9';
        
        -- Agregar campos de niveles según disponibilidad
        IF v_niveles >= 1 THEN
            v_insert_sql := v_insert_sql || ', lugarpagoid1';
            v_values_sql := v_values_sql || ', $10';
            RAISE NOTICE 'Agregando campo INSERT nivel 1: lugarpagoid1 = %', v_plugarpagoid;
        END IF;
        
        IF v_niveles >= 2 THEN
            v_insert_sql := v_insert_sql || ', departamentoid';
            v_values_sql := v_values_sql || ', $11';
            RAISE NOTICE 'Agregando campo INSERT nivel 2: departamentoid = %', v_pdepartamentoid;
        END IF;
        
        IF v_niveles >= 3 THEN
            v_insert_sql := v_insert_sql || ', centrocosto';
            v_values_sql := v_values_sql || ', $12';
            RAISE NOTICE 'Agregando campo INSERT nivel 3: centrocosto = %', v_pcentrocosto;
        END IF;
        
        IF v_niveles >= 4 THEN
            v_insert_sql := v_insert_sql || ', divisionid';
            v_values_sql := v_values_sql || ', $13';
            RAISE NOTICE 'Agregando campo INSERT nivel 4: divisionid = %', v_pdivisionid;
        END IF;
        
        IF v_niveles = 5 THEN
            v_insert_sql := v_insert_sql || ', quintonivelid';
            v_values_sql := v_values_sql || ', $14';
            RAISE NOTICE 'Agregando campo INSERT nivel 5: quintonivelid = %', v_pquintonivelid;
        END IF;
        
        -- Agregar campos fijos finales
        v_insert_sql := v_insert_sql || ', fechatermino, idS3, agrupadorid)';
        v_values_sql := v_values_sql || ', $15, $16, $17)';
        
        -- Construir SQL completo
        v_insert_sql := v_insert_sql || v_values_sql;
        
        RAISE NOTICE 'INSERT SQL construido: %', v_insert_sql;
        
        -- Ejecutar INSERT dinámico
        EXECUTE v_insert_sql
        USING 
            p_ptipodocumentoid,      -- $1
            p_pempleadoid,           -- $2
            p_pfechadocumento,       -- $3
            NOW(),                   -- $4 (fechacreacion)
            p_pusuarioid,            -- $5
            0,                       -- $6 (indexado)
            p_pnombrearchivo,        -- $7
            0,                       -- $8 (documentoid)
            v_pempresaid,            -- $9
            v_plugarpagoid,          -- $10
            v_pdepartamentoid,       -- $11
            v_pcentrocosto,          -- $12
            v_pdivisionid,           -- $13
            v_pquintonivelid,        -- $14
            p_pfechatermino,         -- $15
            p_pids3,                 -- $16
            p_pagrupadorid;          -- $17
        
        RAISE NOTICE 'Documento indexado insertado exitosamente';
        
    EXCEPTION WHEN OTHERS THEN
        v_error   := 1;
        v_mensaje := SQLERRM;
        RAISE NOTICE 'ERROR en INSERT: %', v_mensaje;
    END;

    -- Devolver resultado en cursor
    OPEN p_refcursor FOR
      SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;
-- FUNCTION: public.sp_importacionagestormasivo_grabar(refcursor, character varying, integer, integer, character varying, date, date, character varying, character varying)

-- DROP FUNCTION IF EXISTS public.sp_importacionagestormasivo_grabar(refcursor, character varying, integer, integer, character varying, date, date, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sp_importacionagestormasivo_grabar(
	p_refcursor refcursor,
	p_pusuarioid character varying,
	p_pid integer,
	p_ptipodocumentoid integer,
	p_pempleadoid character varying,
	p_pfechadocumento date,
	p_pfechatermino date,
	p_pids3 character varying,
	p_pnombrearchivo character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_error           INTEGER := 0;
    v_mensaje         VARCHAR := '';
    v_pempresaid      VARCHAR(10);
    v_departamentoid  VARCHAR(14);
    v_lugarpagoid     VARCHAR(14);
    v_centrocostoid   VARCHAR(10);
    v_divisionid      VARCHAR(14);
    v_quintonivelid   VARCHAR(14);
    v_documentoid     INTEGER;
    v_niveles         INTEGER;
    v_select_sql      TEXT;
    v_insert_sql      TEXT;
    v_values_sql      TEXT;
bEGIN
    -- Log de inicio
    RAISE NOTICE 'INICIO sp_importacionagestormasivo_grabar - Usuario: %, ID: %, Empleado: %', p_pusuarioid, p_pid, p_pempleadoid;
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Verificar que exista registro pendiente
    PERFORM 1
      FROM documentosindexar
     WHERE id = p_pid
       AND indexado = 0;
    IF NOT FOUND THEN
        v_error := 1;
        v_mensaje := 'Registro no existe o ya indexado';
        RAISE NOTICE 'ERROR: Registro no existe o ya indexado - ID: %', p_pid;
    ELSE
        BEGIN
            -- Construir SELECT dinámico según niveles disponibles
            v_select_sql := 'SELECT rutempresa';
            
            -- Agregar campos según niveles disponibles
            IF v_niveles >= 1 THEN
                v_select_sql := v_select_sql || ', lugarpagoid';
                RAISE NOTICE 'Agregando campo nivel 1: lugarpagoid';
            END IF;
            
            IF v_niveles >= 2 THEN
                v_select_sql := v_select_sql || ', departamentoid';
                RAISE NOTICE 'Agregando campo nivel 2: departamentoid';
            END IF;
            
            IF v_niveles >= 3 THEN
                v_select_sql := v_select_sql || ', centrocostoid';
                RAISE NOTICE 'Agregando campo nivel 3: centrocostoid';
            END IF;
            
            IF v_niveles >= 4 THEN
                v_select_sql := v_select_sql || ', divisionid';
                RAISE NOTICE 'Agregando campo nivel 4: divisionid';
            END IF;
            
            IF v_niveles = 5 THEN
                v_select_sql := v_select_sql || ', quintonivelid';
                RAISE NOTICE 'Agregando campo nivel 5: quintonivelid';
            END IF;
            
            v_select_sql := v_select_sql || ' FROM empleados WHERE empleadoid = $1';
            
            RAISE NOTICE 'SELECT SQL construido: %', v_select_sql;
            
            -- Obtener datos del empleado según niveles disponibles
            EXECUTE v_select_sql 
            INTO v_pempresaid, v_lugarpagoid, v_departamentoid, v_centrocostoid, v_divisionid, v_quintonivelid
            USING p_pempleadoid;

            -- Construir INSERT dinámico para g_documentosinfo
            v_insert_sql := 'INSERT INTO g_documentosinfo(
                tipodocumentoid, empleadoid, empresaid,
                fechadocumento, fechacreacion, origen,
                usuarioid';
            
            v_values_sql := ' VALUES ($1, $2, $3, $4, $5, $6, $7';
            
            -- Agregar campos de niveles según disponibilidad
            IF v_niveles >= 1 THEN
                v_insert_sql := v_insert_sql || ', lugarpagoid1';
                v_values_sql := v_values_sql || ', $8';
                RAISE NOTICE 'Agregando campo INSERT nivel 1: lugarpagoid1 = %', v_lugarpagoid;
            END IF;
            
            IF v_niveles >= 2 THEN
                v_insert_sql := v_insert_sql || ', departamentoid';
                v_values_sql := v_values_sql || ', $9';
                RAISE NOTICE 'Agregando campo INSERT nivel 2: departamentoid = %', v_departamentoid;
            END IF;
            
            IF v_niveles >= 3 THEN
                v_insert_sql := v_insert_sql || ', centrocostoid';
                v_values_sql := v_values_sql || ', $10';
                RAISE NOTICE 'Agregando campo INSERT nivel 3: centrocostoid = %', v_centrocostoid;
            END IF;
            
            IF v_niveles >= 4 THEN
                v_insert_sql := v_insert_sql || ', divisionid';
                v_values_sql := v_values_sql || ', $11';
                RAISE NOTICE 'Agregando campo INSERT nivel 4: divisionid = %', v_divisionid;
            END IF;
            
            IF v_niveles = 5 THEN
                v_insert_sql := v_insert_sql || ', quintonivelid';
                v_values_sql := v_values_sql || ', $12';
                RAISE NOTICE 'Agregando campo INSERT nivel 5: quintonivelid = %', v_quintonivelid;
            END IF;
            
            -- Agregar campos fijos finales
            v_insert_sql := v_insert_sql || ', fechatermino, idS3, nombrearchivo)';
            v_values_sql := v_values_sql || ', $13, $14, $15) RETURNING documentoid';
            
            -- Construir SQL completo
            v_insert_sql := v_insert_sql || v_values_sql;
            
            RAISE NOTICE 'INSERT SQL construido: %', v_insert_sql;
            
            -- Ejecutar INSERT dinámico
            EXECUTE v_insert_sql
            INTO v_documentoid
            USING 
                p_ptipodocumentoid,      -- $1
                p_pempleadoid,           -- $2
                v_pempresaid,            -- $3
                p_pfechadocumento,       -- $4
                NOW(),                   -- $5 (fechacreacion)
                5,                       -- $6 (origen fijo)
                p_pusuarioid,            -- $7
                v_lugarpagoid,           -- $8
                v_departamentoid,        -- $9
                v_centrocostoid,         -- $10
                v_divisionid,            -- $11
                v_quintonivelid,         -- $12
                p_pfechatermino,         -- $13
                p_pids3,                 -- $14
                p_pnombrearchivo;        -- $15
            
            RAISE NOTICE 'Documento insertado exitosamente. ID: %', v_documentoid;

            -- Marcar como indexado
            UPDATE documentosindexar
               SET indexado           = 1,
                   tipodocumentoid    = p_ptipodocumentoid,
                   fechadocumento     = p_pfechadocumento,
                   empleadoid         = p_pempleadoid,
                   documentoid        = v_documentoid,
                   usuarioiddigitacion= p_pusuarioid,
                   fechadigitacion    = NOW(),
                   idS3               = p_pidS3,
                   nombrearchivo      = p_pnombrearchivo
             WHERE id = p_pid;
             
            RAISE NOTICE 'Registro marcado como indexado exitosamente';
            
        EXCEPTION WHEN OTHERS THEN
            v_error   := 1;
            v_mensaje := SQLERRM;
            RAISE NOTICE 'ERROR en INSERT/UPDATE: %', v_mensaje;
        END;
    END IF;

    -- Devolver estado en cursor
    OPEN p_refcursor FOR
      SELECT v_error AS error, v_mensaje AS mensaje;
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_importacionagestormasivo_obtener_digitacion(refcursor, character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_importacionagestormasivo_obtener_digitacion(refcursor, character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_importacionagestormasivo_obtener_digitacion(
	p_refcursor refcursor,
	pusuarioid character varying,
	pestado integer,
	pid integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    IF pestado = 0 THEN
        IF EXISTS (
            SELECT 1 FROM documentosindexar 
            WHERE indexado = 0 AND id > pid
        ) THEN
            OPEN p_refcursor FOR
            SELECT 
                id AS "documentoid",
                tipodocumentoid AS "tipodocumentoid",
                empleadoid AS "empleadoid",
                TO_CHAR(fechadocumento, 'DD-MM-YYYY') AS "fechadocumento",
                TO_CHAR(fechacreacion, 'DD-MM-YYYY') AS "fechacreacion",
                TO_CHAR(fechatermino, 'DD-MM-YYYY') AS "fechatermino",
                usuarioid AS "usuarioid",
                idS3 AS "idS3",
                nombrearchivo AS "nombrearchivo",
                agrupadorid AS "agrupadorid"
            FROM documentosindexar
            WHERE indexado = 0 AND id > pid
            ORDER BY id ASC
            LIMIT 1;
        ELSE
            OPEN p_refcursor FOR
            SELECT 
                id AS "documentoid",
                tipodocumentoid AS "tipodocumentoid",
                empleadoid AS "empleadoid",
                TO_CHAR(fechadocumento, 'DD-MM-YYYY') AS "fechadocumento",
                TO_CHAR(fechacreacion, 'DD-MM-YYYY') AS "fechacreacion",
                TO_CHAR(fechatermino, 'DD-MM-YYYY') AS "fechatermino",
                usuarioid AS "usuarioid",
                idS3 AS "idS3",
                nombrearchivo AS "nombrearchivo",
                agrupadorid AS "agrupadorid"
            FROM documentosindexar
            WHERE indexado = 0
            ORDER BY id ASC
            LIMIT 1;
        END IF;
    END IF;

    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;-- FUNCTION: public.sp_panel_obtenerporperfil(refcursor, character varying)

-- DROP FUNCTION IF EXISTS public.sp_panel_obtenerporperfil(refcursor, character varying);

CREATE OR REPLACE FUNCTION public.sp_panel_obtenerporperfil(
	p_refcursor refcursor,
	p_usuarioid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_ptipousuarioid int;
    var_totaldoc       int;  -- Declarada, aunque no se utiliza en la lógica final
    var_xfecha         char(10);
    var_xnombre        varchar(300);
    v_niveles          integer;
    var_sql            text;
    var_join_permisos  text;
BEGIN
    -- Log de inicio
    RAISE NOTICE 'INICIO sp_panel_obtenerporperfil - Usuario: %', COALESCE(p_usuarioid, 'NULL');
    
    -- Obtener niveles dinámicamente
    SELECT COALESCE(public.CONSULTAR_NIVELES(), 0) INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Obtener la fecha y el nombre del último editor (equivalente a SELECT TOP 1 ... ORDER BY ... DESC)
    SELECT TO_CHAR(ce.fechainicio, 'DD-MM-YYYY'),
           COALESCE(pe.nombre, '') || ' ' || COALESCE(pe.appaterno, '') || ' ' || COALESCE(pe.apmaterno, '')
      INTO var_xfecha, var_xnombre
      FROM confimpencabezado ce
      LEFT JOIN personas pe ON ce.usuarioid = pe.personaid
      ORDER BY ce.fechainicio DESC
      LIMIT 1;
    
    -- Si no hay datos, asignar valores por defecto
    var_xfecha := COALESCE(var_xfecha, 'N/A');
    var_xnombre := COALESCE(var_xnombre, 'N/A');
      
    -- Obtener el tipo de usuario
    SELECT tipousuarioid 
      INTO var_ptipousuarioid
      FROM usuarios
      WHERE usuarioid = p_usuarioid;
    
    -- Validar que el usuario existe
    IF var_ptipousuarioid IS NULL THEN
        RAISE NOTICE 'ADVERTENCIA: Usuario % no encontrado o sin tipousuarioid', p_usuarioid;
        var_ptipousuarioid := 0; -- Valor por defecto que no coincidirá con ningún tipo
    END IF;
    
    RAISE NOTICE 'Tipo de usuario: %', var_ptipousuarioid;
    
    -- Construir JOIN de permisos dinámicamente según el nivel más alto disponible
    RAISE NOTICE 'Construyendo JOIN de permisos para nivel: %', v_niveles;
    
    IF v_niveles = 1 THEN
        var_join_permisos := '
        INNER JOIN accesoxusuariolugarespago ALP ON ALP.empresaid = c.rutempresa
            AND ALP.lugarpagoid = cdv.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Usando permisos nivel 1: accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_join_permisos := '
        INNER JOIN accesoxusuariodepartamentos ACC ON ACC.empresaid = c.rutempresa
            AND ACC.lugarpagoid = cdv.lugarpagoid
            AND ACC.departamentoid = cdv.departamentoid
            AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Usando permisos nivel 2: accesoxusuariodepartamentos';
    ELSIF v_niveles = 3 THEN
        var_join_permisos := '
        INNER JOIN accesoxusuarioccosto ACC ON ACC.empresaid = c.rutempresa
            AND ACC.lugarpagoid = cdv.lugarpagoid
            AND ACC.departamentoid = cdv.departamentoid
            AND ACC.centrocostoid = cdv.centrocosto
            AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Usando permisos nivel 3: accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_join_permisos := '
        INNER JOIN accesoxusuariodivision ADIV ON ADIV.empresaid = c.rutempresa
            AND ADIV.lugarpagoid = cdv.lugarpagoid
            AND ADIV.departamentoid = cdv.departamentoid
            AND ADIV.centrocostoid = cdv.centrocosto
            AND ADIV.divisionid = cdv.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Usando permisos nivel 4: accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_join_permisos := '
        INNER JOIN accesoxusuarioquintonivel AQN ON AQN.empresaid = c.rutempresa
            AND AQN.lugarpagoid = cdv.lugarpagoid
            AND AQN.departamentoid = cdv.departamentoid
            AND AQN.centrocostoid = cdv.centrocosto
            AND AQN.divisionid = cdv.divisionid
            AND AQN.quintonivelid = cdv.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Usando permisos nivel 5: accesoxusuarioquintonivel';
    ELSE
        -- Si no hay niveles configurados, no aplicar filtro de permisos (o lanzar error)
        var_join_permisos := '';
        RAISE NOTICE 'ADVERTENCIA: No hay niveles configurados. No se aplicarán permisos.';
    END IF;
    
    -- Construir la consulta completa con SQL dinámico
    var_sql := '
    WITH tdocxperfil AS (
      SELECT 
         c.iddocumento,
         c.idestado
      FROM contratos c
      INNER JOIN plantillas pl ON pl.idplantilla = c.idplantilla
      INNER JOIN tiposdocumentosxperfil t ON pl.idtipodoc = t.idtipodoc		
      INNER JOIN empresas e ON e.rutempresa = c.rutempresa
      INNER JOIN contratodatosvariables cdv ON cdv.iddocumento = c.iddocumento'
      || var_join_permisos || '
      LEFT JOIN fichasdocumentos fd ON c.iddocumento = fd.documentoid AND fd.idfichaorigen = 2
      WHERE c.eliminado = false
        AND tipousuarioid = ' || var_ptipousuarioid || '
    ),
    documentostabla AS (
      SELECT 
         CASE t.idestado
            WHEN 1 THEN ''DocumentosOtros''
            WHEN 7 THEN ''DocumentosOtros''
            WHEN 2 THEN ''DocumentosEnProceso''
            WHEN 3 THEN ''DocumentosEnProceso''
            WHEN 9 THEN ''DocumentosEnProceso''
            WHEN 10 THEN ''DocumentosEnProceso''
            WHEN 11 THEN ''DocumentosEnProceso''
            WHEN 12 THEN ''DocumentosEnProceso''
            WHEN 8 THEN ''Rechazados''
            WHEN 6 THEN ''DocumentosFirmados''
            ELSE ''DocumentosOtros''
         END AS descripcion,
         COUNT(DISTINCT t.iddocumento) AS total
      FROM tdocxperfil t
      INNER JOIN contratosestados ce ON ce.idestado = t.idestado
      GROUP BY t.idestado
    ),
    sourcetable AS (
       SELECT descripcion, SUM(total) AS total
       FROM documentostabla
       GROUP BY descripcion
       UNION ALL
       SELECT ''TotalDocumentos'', (SELECT SUM(total) FROM documentostabla)
    )
    SELECT 
        ''Panel'' AS "Total",
        COALESCE(SUM(CASE WHEN descripcion = ''DocumentosEnProceso'' THEN total END), 0) AS "DocumentosEnProceso",
        COALESCE(SUM(CASE WHEN descripcion = ''DocumentosFirmados'' THEN total END), 0) AS "DocumentosFirmados",
        COALESCE(SUM(CASE WHEN descripcion = ''DocumentosOtros'' THEN total END), 0) AS "DocumentosOtros",
        COALESCE(SUM(CASE WHEN descripcion = ''Rechazados'' THEN total END), 0) AS "Rechazado",
        COALESCE(SUM(CASE WHEN descripcion = ''TotalDocumentos'' THEN total END), 0) AS "TotalDocumentos",
        COALESCE(' || quote_literal(var_xfecha) || ', ''N/A'') AS "FechaUltimoEditor",
        COALESCE(' || quote_literal(var_xnombre) || ', ''N/A'') AS "NombreUltimoEditor"
    FROM sourcetable';
    
    -- Log de la consulta SQL construida
    RAISE NOTICE 'Consulta SQL final construida (primeros 800 caracteres): %', LEFT(var_sql, 800);
    
    -- Validar que la consulta SQL no sea NULL
    IF var_sql IS NULL THEN
        RAISE EXCEPTION 'Error: La consulta SQL construida es NULL. v_niveles=%, var_ptipousuarioid=%, var_xfecha=%, var_xnombre=%', 
            v_niveles, var_ptipousuarioid, var_xfecha, var_xnombre;
    END IF;
    
    -- Ejecutar la consulta dinámica
    RAISE NOTICE 'Ejecutando consulta con niveles dinámicos';
    OPEN p_refcursor FOR EXECUTE var_sql;
    
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_panel_obtenerporperfil: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_panel_obtenerporperfil: %', SQLERRM;
END;
$BODY$;

-- FUNCTION: public.sp_personas_obtenernombre(refcursor, character varying)

-- DROP FUNCTION IF EXISTS public.sp_personas_obtenernombre(refcursor, character varying);

CREATE OR REPLACE FUNCTION public.sp_personas_obtenernombre(
	p_refcursor refcursor,
	p_personaid character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    dato integer := 0;
    v_niveles integer;
    var_sql text;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    -- Verificar existencia del usuario
    IF EXISTS (SELECT 1 FROM usuarios WHERE usuarioid = p_personaid) THEN
        dato := 1;
    END IF;

    -- Construir consulta base
    var_sql := '
    SELECT 
        p.personaid AS "personaid", 
        COALESCE(p.nombre,'''') AS "nombre", 
        COALESCE(p.appaterno,'''') AS "appaterno", 
        COALESCE(p.apmaterno,'''') AS "apmaterno",
        p.correo AS "correo",
        p.nacionalidad AS "nacionalidad",
        p.direccion AS "direccion",
        p.comuna AS "comuna",
        p.ciudad AS "ciudad",
        p.region AS "region",
        to_char(p.fechanacimiento, ''DD-MM-YYYY'') AS "fechanacimiento",
        to_char(p.fechanacimiento, ''DD-MM-YYYY'') AS "FechaNacimiento",
        p.estadocivil AS "estadocivil",
        e.rolid AS "rolid",
        u.idfirma AS "idFirma",
        f.descripcion AS "Descripcion",
        p.fono AS "fono", 
        e.idestadoempleado AS "idEstadoEmpleado",
        p.correoinstitucional AS "correoinstitucional",
        ' || dato || ' AS "existe",
        e.rutempresa AS "RutEmpresa"';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ',
        e.lugarpagoid AS "lugarpagoid",
        lp.nombrelugarpago AS "nombrelugarpago"';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ',
        e.departamentoid AS "departamentoid",
        de.nombredepartamento AS "nombredepartamento"';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ',
        e.centrocostoid AS "idCentroCosto",
        cc.nombrecentrocosto AS "nombrecentrocosto"';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ',
        e.divisionid AS "divisionid",
        div.nombredivision AS "nombredivision"';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || ',
        e.quintonivelid AS "quintonivelid",
        qn.nombrequintonivel AS "nombrequintonivel"';
    END IF;

    -- FROM y JOINs base
    var_sql := var_sql || '
    FROM personas p 
    LEFT JOIN empleados e ON e.empleadoid = p.personaid
    LEFT JOIN usuarios u ON p.personaid = u.usuarioid
    LEFT JOIN firmas f ON u.idfirma = f.idfirma';

    -- JOINs de niveles dinámicos
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
    LEFT JOIN lugarespago lp ON lp.empresaid = e.rutempresa AND lp.lugarpagoid = e.lugarpagoid';
    END IF;
    
    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
    LEFT JOIN departamentos de ON de.empresaid = e.rutempresa AND de.lugarpagoid = e.lugarpagoid AND de.departamentoid = e.departamentoid';
    END IF;
    
    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
    LEFT JOIN centroscosto cc ON cc.empresaid = e.rutempresa AND cc.lugarpagoid = e.lugarpagoid AND cc.departamentoid = e.departamentoid AND cc.centrocostoid = e.centrocostoid';
    END IF;
    
    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
    LEFT JOIN division div ON div.empresaid = e.rutempresa AND div.lugarpagoid = e.lugarpagoid AND div.departamentoid = e.departamentoid AND div.centrocostoid = e.centrocostoid AND div.divisionid = e.divisionid';
    END IF;
    
    IF v_niveles = 5 THEN
        var_sql := var_sql || '
    LEFT JOIN quinto_nivel qn ON qn.empresaid = e.rutempresa AND qn.lugarpagoid = e.lugarpagoid AND qn.departamentoid = e.departamentoid AND qn.centrocostoid = e.centrocostoid AND qn.divisionid = e.divisionid AND qn.quintonivelid = e.quintonivelid';
    END IF;

    -- WHERE clause
    var_sql := var_sql || '
    WHERE p.personaid = ''' || p_personaid || ''' AND COALESCE(p.eliminado, false) = false';

    -- Ejecutar consulta dinámica
    OPEN p_refcursor FOR EXECUTE var_sql;

    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_plantillas_clonar(refcursor, integer)

-- DROP FUNCTION IF EXISTS public.sp_plantillas_clonar(refcursor, integer);

CREATE OR REPLACE FUNCTION public.sp_plantillas_clonar(
	p_refcursor refcursor,
	p_idplantilla integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor ALIAS FOR p_refcursor;
    var_idplan INTEGER := 0;
    var_error INTEGER := 0;
    var_mensaje VARCHAR := '';
BEGIN
    BEGIN
        -- Insertar nueva plantilla clonando los datos y obtener el ID generado
        INSERT INTO plantillas (
            descripcion_pl, titulo_pl, idwf, aprobado, idtipodoc, rutmodificador, rutaprobador,
            idcategoria, idtipogestor, eliminado
        )
        SELECT
            descripcion_pl || '(Copia)',
            titulo_pl || '(Copia)',
            idwf,
            false,
            idtipodoc,
            rutmodificador,
            rutaprobador,
            idcategoria,
            idtipogestor,
            false
        FROM plantillas
        WHERE idplantilla = p_idplantilla
        RETURNING idplantilla INTO var_idplan;

        -- Copiar cláusulas
        INSERT INTO plantillasclausulas (idplantilla, idclausula, orden, encabezado, titulo)
        SELECT var_idplan, idclausula, orden, encabezado, titulo
        FROM plantillasclausulas
        WHERE idplantilla = p_idplantilla;

    EXCEPTION WHEN OTHERS THEN
        var_error := 1;
        var_mensaje := SQLERRM;
        var_idplan := 0;
    END;

    OPEN var_cursor FOR
    SELECT var_error AS "error", var_mensaje AS "mensaje", var_idplan AS "idPlantilla";
    RETURN var_cursor;
END;
$BODY$;

-- FUNCTION: public.sp_plantillas_obtenerclausulasplantillas(refcursor, integer)

-- DROP FUNCTION IF EXISTS public.sp_plantillas_obtenerclausulasplantillas(refcursor, integer);

CREATE OR REPLACE FUNCTION public.sp_plantillas_obtenerclausulasplantillas(
	p_refcursor refcursor,
	p_idplantilla integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN
    -- Abrir cursor con cláusulas asociadas a la plantilla
    OPEN p_refcursor FOR
      SELECT
        c.idclausula       AS "idClausula",
        c.titulo_cl        AS "Titulo_Cl",
        c.descripcion_cl   AS "Descripcion_Cl",
        c.texto            AS "Texto",
        cat.idcategoria    AS "idCategoria",
        cat.titulo         AS "TituloCategoria",
        CASE WHEN c.aprobado = true THEN 1 ELSE 0 END AS "Aprobado",
        p.idplantilla      AS "idPlantilla",
        pc.orden           AS "Orden",
        p.titulo_pl        AS "Titulo_Pl",
        CASE WHEN pc.encabezado = true THEN 1 ELSE 0 END AS "Encabezado",
        CASE WHEN pc.titulo = true THEN 1 ELSE 0 END AS "Titulo",
        CASE WHEN COALESCE(pc.saltopagina, 0) = 1 THEN 1 ELSE 0 END AS "SaltoPagina",
        CASE WHEN COALESCE(pc.saltopagina, 0) = 1 THEN 'checked' ELSE '' END AS marcacheck
      FROM plantillas p
      JOIN plantillasclausulas pc
        ON p.idplantilla = pc.idplantilla
      JOIN clausulas c
        ON c.idclausula = pc.idclausula
      JOIN categorias cat
        ON c.idcategoria = cat.idcategoria
     WHERE pc.idplantilla = p_idPlantilla
       AND c.eliminado = false
     ORDER BY pc.orden ASC;
    RETURN p_refcursor;
END;
$BODY$;

-- FUNCTION: public.sp_procesos_todos(refcursor, integer, integer, numeric, character varying, character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_procesos_todos(refcursor, integer, integer, numeric, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_procesos_todos(
	p_refcursor refcursor,
	p_ptipousuarioid integer,
	p_pagina integer,
	p_decuantos numeric,
	p_buscar character varying,
	p_pusuarioid character varying,
	p_pestado integer,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_pinicio      integer;
    v_pfin         integer;
    v_rolid        integer;
    v_buscar_like  varchar(50);
    v_sql          text;
    v_niveles      integer;
    var_log_message text;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_procesos_todos - Usuario: ' || COALESCE(p_pusuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    -- rangos de paginación
    v_pinicio := (p_pagina - 1) * p_decuantos + 1;
    v_pfin    := p_pagina * p_decuantos;
    v_buscar_like := '%' || COALESCE(p_buscar, '') || '%';

    -- rol del usuario
    SELECT rolid INTO v_rolid
    FROM usuarios
    WHERE usuarioid = p_pusuarioid;

    v_sql := '
        WITH DocumentosTabla AS (
            SELECT
                p.idproceso       AS "idProceso",
                p.descripcion     AS "Descripcion",
                COUNT(*)          AS "CantDocumentos",
                ROW_NUMBER() OVER (ORDER BY p.idproceso) AS "RowNum"
            FROM procesos p
            JOIN contratos c              ON c.idproceso = p.idproceso
            JOIN plantillas pl            ON pl.idplantilla = c.idplantilla
            JOIN contratodatosvariables cdv ON cdv.iddocumento = c.iddocumento
    ';

    IF p_pestado >= 0 THEN
        -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

        IF v_niveles = 1 THEN
            v_sql := v_sql || '
            JOIN accesoxusuariolugarespago acc
              ON acc.empresaid     = c.rutempresa
             AND acc.lugarpagoid   = cdv.lugarpagoid
             AND acc.usuarioid     = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
        ELSIF v_niveles = 2 THEN
            v_sql := v_sql || '
            JOIN accesoxusuariodepartamentos acc
              ON acc.empresaid     = c.rutempresa
             AND acc.lugarpagoid   = cdv.lugarpagoid
             AND acc.departamentoid= cdv.departamentoid
             AND acc.usuarioid     = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
        ELSIF v_niveles = 3 THEN
            v_sql := v_sql || '
            JOIN accesoxusuarioccosto acc
              ON acc.empresaid     = c.rutempresa
             AND acc.lugarpagoid   = cdv.lugarpagoid
             AND acc.departamentoid= cdv.departamentoid
             AND acc.centrocostoid = cdv.centrocosto
             AND acc.usuarioid     = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
        ELSIF v_niveles = 4 THEN
            v_sql := v_sql || '
            JOIN accesoxusuariodivision acc
              ON acc.empresaid     = c.rutempresa
             AND acc.lugarpagoid   = cdv.lugarpagoid
             AND acc.departamentoid= cdv.departamentoid
             AND acc.centrocostoid = cdv.centrocosto
             AND acc.divisionid    = cdv.divisionid
             AND acc.usuarioid     = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
        ELSIF v_niveles = 5 THEN
            v_sql := v_sql || '
            JOIN accesoxusuarioquintonivel acc
              ON acc.empresaid     = c.rutempresa
             AND acc.lugarpagoid   = cdv.lugarpagoid
             AND acc.departamentoid= cdv.departamentoid
             AND acc.centrocostoid = cdv.centrocosto
             AND acc.divisionid    = cdv.divisionid
             AND acc.quintonivelid = cdv.quintonivelid
             AND acc.usuarioid     = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
        END IF;

        v_sql := v_sql || '
            JOIN tiposdocumentosxperfil t
              ON pl.idplantilla = t.idtipodoc
             AND t.tipousuarioid = $2
        ';
    ELSE
        v_sql := v_sql || '
            JOIN contratofirmantes cf
              ON cf.iddocumento = c.iddocumento
             AND cf.rutfirmante = $1
             AND cf.idestado    = c.idestado
        ';
    END IF;

    IF v_rolid = 2 THEN
        v_sql := v_sql || '
            JOIN empleados emp
              ON cdv.rut = emp.empleadoid
             AND emp.rolid = $3
        ';
    END IF;

    -- Nota: si "eliminado" es INT (0/1) en tu PG, cambia "false" por 0.
    v_sql := v_sql || '
            WHERE p.eliminado = false
              AND c.eliminado = false
    ';

    IF COALESCE(p_buscar,'') <> '' THEN
        v_sql := v_sql || '  AND p.descripcion ILIKE $4 ';
    END IF;

    IF p_pestado > 0 THEN
        v_sql := v_sql || '  AND c.idestado = $5 ';
    ELSIF p_pestado < 0 THEN
        v_sql := v_sql || '  AND c.idestado IN (2,3,10) ';
    END IF;

    v_sql := v_sql || '
            GROUP BY p.idproceso, p.descripcion
        )
        SELECT "idProceso", "Descripcion", "CantDocumentos", "RowNum"
        FROM DocumentosTabla
        WHERE "RowNum" BETWEEN $6 AND $7
    ';

    IF p_debug = 1 THEN
        RAISE NOTICE '%', v_sql;
    END IF;

    -- Abrir el cursor con parámetros seguros
    OPEN p_refcursor FOR EXECUTE v_sql
        USING
            p_pusuarioid,          -- $1
            p_ptipousuarioid,      -- $2
            v_rolid,               -- $3
            v_buscar_like,         -- $4
            p_pestado,             -- $5
            v_pinicio,             -- $6
            v_pfin;                -- $7

    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_procesos_total(refcursor, integer, integer, numeric, character varying, character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_procesos_total(refcursor, integer, integer, numeric, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_procesos_total(
	p_cursor refcursor,
	p_tipo_usuario_id integer,
	p_pagina integer,
	p_de_cuantos numeric,
	p_buscar character varying,
	p_usuario_id character varying,
	p_estado integer,
	p_debug integer DEFAULT 0)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_total INTEGER;
    v_total_orig INTEGER;
    v_total_reg DECIMAL(9,2);
    v_decimal DECIMAL(9,2);
    
    v_p_inicio INTEGER;
    v_p_fin INTEGER;
    v_nl CHAR(2) := CHR(13) || CHR(10);
    v_buscar_like VARCHAR(50);
    
    v_sql_string TEXT;
    v_rol_id INTEGER;
    v_mensaje VARCHAR(100);
    v_parametros TEXT;
    v_niveles INTEGER;
    var_log_message TEXT;
BEGIN
    -- Log de inicio
    var_log_message := 'INICIO sp_procesos_total - Usuario: ' || COALESCE(p_usuario_id, 'NULL');
    RAISE NOTICE '%', var_log_message;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;

    v_p_inicio := (p_pagina - 1) * p_de_cuantos + 1;
    v_p_fin := p_pagina * p_de_cuantos;
    
    v_buscar_like := '%' || p_buscar || '%';
    
    -- Buscar el rol del usuario
    SELECT rolid INTO v_rol_id FROM usuarios WHERE usuarioid = p_usuario_id;
    
    v_sql_string := '
        WITH DocumentosTabla AS (
            SELECT 
                P.idproceso
            FROM 
                procesos P 
            INNER JOIN contratos C ON C.idproceso = P.idproceso
            INNER JOIN plantillas PL ON PL.idplantilla = C.idplantilla 
            INNER JOIN contratodatosvariables CDV ON CDV.iddocumento = C.iddocumento 
            ';
    
    IF (p_estado >= 0) THEN
        -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
        RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

        IF v_niveles = 1 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariolugarespago ACC ON 
                ACC.empresaid = C.rutempresa AND 
                ACC.lugarpagoid = CDV.lugarpagoid AND 
                ACC.usuarioid = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 1: accesoxusuariolugarespago';
        ELSIF v_niveles = 2 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodepartamentos ACC ON 
                ACC.empresaid = C.rutempresa AND 
                ACC.lugarpagoid = CDV.lugarpagoid AND 
                ACC.departamentoid = CDV.departamentoid AND  
                ACC.usuarioid = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 2: accesoxusuariodepartamentos';
        ELSIF v_niveles = 3 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioccosto ACC ON 
                ACC.empresaid = C.rutempresa AND 
                ACC.lugarpagoid = CDV.lugarpagoid AND 
                ACC.departamentoid = CDV.departamentoid AND
                ACC.centrocostoid = CDV.centrocosto AND
                ACC.usuarioid = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 3: accesoxusuarioccosto';
        ELSIF v_niveles = 4 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuariodivision ACC ON 
                ACC.empresaid = C.rutempresa AND 
                ACC.lugarpagoid = CDV.lugarpagoid AND 
                ACC.departamentoid = CDV.departamentoid AND
                ACC.centrocostoid = CDV.centrocosto AND
                ACC.divisionid = CDV.divisionid AND
                ACC.usuarioid = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 4: accesoxusuariodivision';
        ELSIF v_niveles = 5 THEN
            v_sql_string := v_sql_string || '
            INNER JOIN accesoxusuarioquintonivel ACC ON 
                ACC.empresaid = C.rutempresa AND 
                ACC.lugarpagoid = CDV.lugarpagoid AND 
                ACC.departamentoid = CDV.departamentoid AND
                ACC.centrocostoid = CDV.centrocosto AND
                ACC.divisionid = CDV.divisionid AND
                ACC.quintonivelid = CDV.quintonivelid AND
                ACC.usuarioid = $1';
            RAISE NOTICE 'Agregando JOIN de permisos nivel 5: accesoxusuarioquintonivel';
        END IF;

        v_sql_string := v_sql_string || '
            INNER JOIN tiposdocumentosxperfil T ON PL.idplantilla = T.idtipodoc AND T.tipousuarioid = $2
            ';
    END IF;
    
    IF (p_estado < 0) THEN
        v_sql_string := v_sql_string || '
            INNER JOIN contratofirmantes CF ON CF.iddocumento = C.iddocumento AND CF.rutfirmante = $1 AND CF.idestado = C.idestado
            ';
    END IF;
    
    -- Validar el rol
    IF (v_rol_id = 2) THEN -- 1: Privado y 2: Público
        v_sql_string := v_sql_string || ' INNER JOIN empleados Emp ON CDV.rut = Emp.empleadoid AND Emp.rolid = $3 ';
    END IF;
    
    v_sql_string := v_sql_string || ' WHERE P.eliminado = false AND C.eliminado = false';
    
    IF (p_buscar != '') THEN
        v_sql_string := v_sql_string || ' AND P.descripcion LIKE $4';
    END IF;
    
    IF (p_estado > 0) THEN
        v_sql_string := v_sql_string || ' AND C.idestado = $5';
    END IF;
    
    IF (p_estado < 0) THEN
        v_sql_string := v_sql_string || ' AND C.idestado IN (2,3,10)';
    END IF;
    
    v_sql_string := v_sql_string || ' GROUP BY P.idproceso, P.descripcion
        )
        SELECT COUNT(idproceso) FROM DocumentosTabla';
    
    IF (p_debug = 1) THEN
        RAISE NOTICE 'SQL: %', v_sql_string;
    END IF;
    
    -- Ejecutar la consulta dinámica
    EXECUTE v_sql_string 
    INTO v_total_orig
    USING p_usuario_id, p_tipo_usuario_id, v_rol_id, v_buscar_like, p_estado;
    
    v_total_reg := (v_total_orig / p_de_cuantos);
    v_decimal := v_total_reg - FLOOR(v_total_reg);
    
    IF v_decimal > 0 THEN
        v_total := FLOOR(v_total_reg) + 1;
    ELSE
        v_total := FLOOR(v_total_reg);
    END IF;
    
    v_total_reg := v_total_reg * p_de_cuantos;
    
    -- Abrir el cursor con el resultado
    OPEN p_cursor FOR
    SELECT v_total AS total, v_total_reg AS totalreg;
    
    -- Retornar el cursor
    RETURN p_cursor;
END;
$BODY$;


-- FUNCTION: public.sp_pt_gestorpersonas_listaxtipodoc(refcursor, text, text, integer, integer, text, date, date, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_pt_gestorpersonas_listaxtipodoc(refcursor, text, text, integer, integer, text, date, date, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_pt_gestorpersonas_listaxtipodoc(
	p_refcursor refcursor,
	p_pempleadoid text,
	p_pusuarioid text,
	p_ptipodocumentoid integer,
	p_ptipousuarioid integer,
	p_pnumerocontrato text,
	p_pfechadesde date,
	p_pfechahasta date,
	p_pagina integer,
	p_decuantos integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_limit integer;
    v_offset integer;
    v_niveles integer;
    sql text;
    sql_select text;
    sql_joins text;
BEGIN
    -- Parámetros de paginación
    IF p_pagina    IS NULL OR p_pagina    < 1 THEN p_pagina := 1; END IF;
    IF p_decuantos IS NULL OR p_decuantos < 1 THEN p_decuantos := 10; END IF;
    v_limit  := p_decuantos;
    v_offset := (p_pagina - 1) * p_decuantos;

    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'sp_pt_gestorpersonas_listaxtipodoc - Niveles disponibles: %', v_niveles;

    -- Construcción dinámica del SELECT
    sql_select := '
        SELECT
          DOC.documentoid                                            AS "documentoid",
          DOC.tipodocumentoid                                        AS "tipodocumentoid",
          TG.nombre                                                  AS "nombredocumento",
          DOC.empleadoid::text                                       AS "empleadoid",
          CONCAT_WS('' '', COALESCE(PER.nombre,''''), COALESCE(PER.appaterno,''''), COALESCE(PER.apmaterno,'''')) AS "nombre",
          DOC.empresaid                                              AS "empresaid",
          EMP.razonsocial                                            AS "nombreempresa"';

    -- Agregar campos de niveles dinámicamente
    IF v_niveles >= 1 THEN
        sql_select := sql_select || ',
          DOC.lugarpagoid1                                           AS "lugarpagoid",
          LP.nombrelugarpago                                         AS "nombrelugarpago"';
        RAISE NOTICE 'Agregando campos nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        sql_select := sql_select || ',
          DOC.departamentoid                                         AS "departamentoid",
          DP.nombredepartamento                                      AS "nombredepartamento"';
        RAISE NOTICE 'Agregando campos nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        sql_select := sql_select || ',
          DOC.centrocostoid                                          AS "centrocostoid",
          CCO.nombrecentrocosto                                      AS "nombrecentrocosto"';
        RAISE NOTICE 'Agregando campos nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        sql_select := sql_select || ',
          DOC.divisionid                                             AS "divisionid",
          DIV.nombredivision                                         AS "nombredivision"';
        RAISE NOTICE 'Agregando campos nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        sql_select := sql_select || ',
          DOC.quintonivelid                                          AS "quintonivelid",
          QN.nombrequintonivel                                       AS "nombrequintonivel"';
        RAISE NOTICE 'Agregando campos nivel 5: quinto_nivel';
    END IF;

    -- Agregar campos finales
    sql_select := sql_select || ',
          to_char(DOC.fechadocumento, ''DD-MM-YYYY'')                  AS "fechadocumento",
          to_char(DOC.fechacreacion,  ''DD-MM-YYYY'')                  AS "fechacreacion",
          to_char(DOC.fechatermino,   ''DD-MM-YYYY'')                  AS "fechatermino",
          COALESCE(DOC.numerocontrato, 0)::text                      AS "nrocontrato"';

    -- JOINs base
    sql_joins := '
        FROM g_documentosinfo AS DOC
        JOIN g_tiposdocumentosxperfil AS TXP  
          ON TXP.tipodocumentoid = DOC.tipodocumentoid
         AND TXP.tipousuarioid   = ' || p_ptipousuarioid || '
        JOIN empleados AS EMPL 
          ON EMPL.empleadoid = DOC.empleadoid
         AND EMPL.rutempresa = DOC.empresaid
        JOIN tipogestor AS TG   
          ON TG.idtipogestor = DOC.tipodocumentoid
        JOIN personas AS PER  
          ON PER.personaid = EMPL.empleadoid
        JOIN empresas AS EMP  
          ON EMP.rutempresa = DOC.empresaid';

    -- Agregar JOINs de niveles dinámicamente
    IF v_niveles >= 1 THEN
        sql_joins := sql_joins || '
        JOIN lugarespago AS LP   
          ON LP.lugarpagoid = EMPL.lugarpagoid
         AND LP.empresaid   = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        sql_joins := sql_joins || '
        JOIN departamentos AS DP   
          ON DP.departamentoid = EMPL.departamentoid
         AND DP.lugarpagoid    = EMPL.lugarpagoid
         AND DP.empresaid      = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        sql_joins := sql_joins || '
        JOIN centroscosto AS CCO   
          ON CCO.centrocostoid = EMPL.centrocostoid
         AND CCO.lugarpagoid    = EMPL.lugarpagoid
         AND CCO.departamentoid = EMPL.departamentoid
         AND CCO.empresaid      = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        sql_joins := sql_joins || '
        JOIN division AS DIV   
          ON DIV.divisionid      = EMPL.divisionid
         AND DIV.lugarpagoid    = EMPL.lugarpagoid
         AND DIV.departamentoid = EMPL.departamentoid
         AND DIV.centrocostoid  = EMPL.centrocostoid
         AND DIV.empresaid      = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        sql_joins := sql_joins || '
        JOIN quinto_nivel AS QN   
          ON QN.quintonivelid    = EMPL.quintonivelid
         AND QN.lugarpagoid      = EMPL.lugarpagoid
         AND QN.departamentoid   = EMPL.departamentoid
         AND QN.centrocostoid    = EMPL.centrocostoid
         AND QN.divisionid       = EMPL.divisionid
         AND QN.empresaid        = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Construir SQL completo
    sql := sql_select || sql_joins || format($SQL$
        WHERE EMPL.empleadoid = %L
          AND DOC.tipodocumentoid = %s
          %s
          %s
        ORDER BY DOC.fechadocumento
        LIMIT %s OFFSET %s
    $SQL$,
        p_pempleadoid,
        p_ptipodocumentoid,
        CASE WHEN p_pNumeroContrato IS NOT NULL AND p_pNumeroContrato <> ''
             THEN format('AND DOC.documentoid::text = %L', p_pNumeroContrato) 
             ELSE '' 
        END,
        CASE WHEN p_pfechadesde IS NOT NULL AND p_pfechahasta IS NOT NULL
             THEN format('AND DOC.fechadocumento BETWEEN %L::timestamp + interval ''00:00:00.01''
                                             AND %L::timestamp + interval ''23:59:59.99''',
                         p_pfechadesde::text, p_pfechahasta::text)
             ELSE '' 
        END,
        v_limit, 
        v_offset
    );

    RAISE NOTICE 'Consulta SQL construida (primeros 500 caracteres): %', LEFT(sql, 500);

    OPEN p_refcursor FOR EXECUTE sql;
    RETURN p_refcursor;

EXCEPTION
    WHEN OTHERS THEN
        OPEN p_refcursor FOR SELECT format('ERROR: %s', SQLERRM) AS "mensaje";
        RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_pt_gestorpersonas_listaxtipodoc_total(refcursor, text, text, integer, integer, text, date, date, integer)

-- DROP FUNCTION IF EXISTS public.sp_pt_gestorpersonas_listaxtipodoc_total(refcursor, text, text, integer, integer, text, date, date, integer);

CREATE OR REPLACE FUNCTION public.sp_pt_gestorpersonas_listaxtipodoc_total(
	p_refcursor refcursor,
	p_empleadoid text,
	p_usuarioid text,
	p_tipodocumentoid integer,
	p_tipousuarioid integer,
	p_numero_contrato text,
	p_fecha_desde date,
	p_fecha_hasta date,
	p_decuantos integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_sql TEXT;
    var_sql_joins TEXT;
    var_totalreg NUMERIC;
    var_total INT;
    v_niveles INTEGER;
    var_xfechadesde TIMESTAMP;
    var_xfechahasta TIMESTAMP;
BEGIN
    -- Preparar fechas
    IF p_fecha_desde IS NOT NULL THEN
        var_xfechadesde := p_fecha_desde::DATE || ' 00:00:00.01';
    END IF;
    
    IF p_fecha_hasta IS NOT NULL THEN
        var_xfechahasta := p_fecha_hasta::DATE || ' 23:59:59.99';
    END IF;
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'sp_pt_gestorpersonas_listaxtipodoc_total - Niveles disponibles: %', v_niveles;
    
    -- JOINs base
    var_sql_joins := '
            INNER JOIN g_tiposdocumentosxperfil ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
                AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
            INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
                AND EMPL.rutempresa = DOC.empresaid
            INNER JOIN tipogestor AS TG ON TG.idtipogestor = DOC.tipodocumentoid
            INNER JOIN personas AS PER ON PER.personaid = EMPL.empleadoid
            INNER JOIN empresas AS EMP ON EMP.rutempresa = DOC.empresaid';

    -- Agregar JOINs de niveles dinámicamente
    IF v_niveles >= 1 THEN
        var_sql_joins := var_sql_joins || '
            INNER JOIN lugarespago AS LP ON LP.lugarpagoid = EMPL.lugarpagoid
                AND LP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql_joins := var_sql_joins || '
            INNER JOIN departamentos AS DP ON DP.departamentoid = EMPL.departamentoid
                AND DP.lugarpagoid = EMPL.lugarpagoid
                AND DP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql_joins := var_sql_joins || '
            INNER JOIN centroscosto AS CCO ON CCO.centrocostoid = EMPL.centrocostoid
                AND CCO.lugarpagoid = EMPL.lugarpagoid
                AND CCO.departamentoid = EMPL.departamentoid
                AND CCO.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql_joins := var_sql_joins || '
            INNER JOIN division AS DIV ON DIV.divisionid = EMPL.divisionid
                AND DIV.lugarpagoid = EMPL.lugarpagoid
                AND DIV.departamentoid = EMPL.departamentoid
                AND DIV.centrocostoid = EMPL.centrocostoid
                AND DIV.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql_joins := var_sql_joins || '
            INNER JOIN quinto_nivel AS QN ON QN.quintonivelid = EMPL.quintonivelid
                AND QN.lugarpagoid = EMPL.lugarpagoid
                AND QN.departamentoid = EMPL.departamentoid
                AND QN.centrocostoid = EMPL.centrocostoid
                AND QN.divisionid = EMPL.divisionid
                AND QN.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;
    
    -- Construcción de la consulta con CTE
    var_sql := '
        WITH DocumentosTabla AS (
            SELECT DOC.documentoid
            FROM g_documentosinfo AS DOC' || var_sql_joins || '
            WHERE EMPL.empleadoid = ' || quote_literal(p_empleadoid) || '
                AND DOC.tipodocumentoid = ' || p_tipodocumentoid;
    
    -- Filtros condicionales
    IF p_numero_contrato IS NOT NULL AND p_numero_contrato != '' THEN
        var_sql := var_sql || ' AND DOC.documentoid = ' || p_numero_contrato;
    END IF;
    
    IF p_fecha_desde IS NOT NULL THEN
        var_sql := var_sql || ' AND DOC.fechadocumento BETWEEN ' || quote_literal(var_xfechadesde::TEXT) || ' AND ' || quote_literal(var_xfechahasta::TEXT);
    END IF;
    
    -- *** CORRECCIÓN DE LA LÓGICA DE PAGINACIÓN ***
    -- Cierre del CTE + cálculo correcto de paginación
    var_sql := var_sql || ')
        SELECT 
            CEIL(COUNT(*)::NUMERIC / ' || p_decuantos || ')::INT AS "total",
            COUNT(*)::INT AS "totalreg"
        FROM DocumentosTabla';

    RAISE NOTICE 'Consulta SQL de total construida (primeros 500 caracteres): %', LEFT(var_sql, 500);

    -- Abrir cursor
    OPEN p_refcursor FOR EXECUTE var_sql;
    RETURN p_refcursor;

EXCEPTION WHEN OTHERS THEN
    OPEN p_refcursor FOR SELECT 1 AS "error", SQLERRM AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_rbk_documentos_enviogestor(refcursor, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_rbk_documentos_enviogestor(refcursor, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_rbk_documentos_enviogestor(
	p_refcursor refcursor,
	p_piddocumento integer,
	p_debug integer DEFAULT 1)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_iddoc integer;
    var_personaid varchar(10);
    var_cc varchar(14);
    var_em varchar(10);
    var_lp varchar(14);
    var_dep varchar(14);
    var_div varchar(14);
    var_quintonivel varchar(14);
    var_error integer := 0;
    var_mensaje varchar(200);
    var_resultado integer := 0;
    var_resultado2 boolean := false;
    var_origen integer; -- CORREGIDO: ahora es INTEGER
    var_base_gestor varchar(120);
    var_nombrearchivo varchar(100);
    var_idS3 varchar(200);
    var_CDV_idTipoGestor integer;
    var_CDV_fechadocumento date;
    var_CDV_FechaTermino date;
    var_CDV_FechaInicio date;
    var_CDV_idDocumento integer;
    var_CDV_Rut varchar(10);
    var_paso_fecha date;
BEGIN
    -- Corrección: casteo explícito a integer
    SELECT parametro::integer INTO var_origen 
    FROM Parametros 
    WHERE idparametro = 'origen';

    -- Corrección: casteo explícito de empresa a varchar
    SELECT 
        CDV.Rut,
        CDV.CentroCosto,
        C.RutEmpresa::varchar(10),
        CDV.departamentoid,
        CDV.lugarpagoid,
        CDV.divisionid,
        CDV.quintonivelid
    INTO 
        var_personaid, var_cc, var_em, var_dep, var_lp, var_div, var_quintonivel
    FROM Contratos C
    INNER JOIN ContratoDatosVariables CDV ON C.idDocumento = CDV.idDocumento
    WHERE C.idDocumento = p_piddocumento;

    -- Permitimos vacíos (como SQL Server)

    BEGIN
        SELECT 
            PL.idTipoGestor, CDV.Rut, CDV.FechaInicio, CDV.fechadocumento, CDV.FechaTermino, CDV.idDocumento
        INTO 
            var_CDV_idTipoGestor, var_CDV_Rut, var_CDV_FechaInicio, var_CDV_fechadocumento, var_CDV_FechaTermino, var_CDV_idDocumento
        FROM Contratos C
        INNER JOIN ContratoDatosVariables CDV ON C.idDocumento = CDV.idDocumento
        INNER JOIN Plantillas PL ON C.idPlantilla = PL.idPlantilla
        WHERE C.idDocumento = p_piddocumento;

        SELECT idS3, NombreArchivo INTO var_idS3, var_nombrearchivo 
        FROM Contratos 
        WHERE idDocumento = p_piddocumento;

        SELECT COUNT(*) INTO var_resultado FROM g_documentosinfo 
        WHERE NumeroContrato = p_piddocumento AND empleadoid = var_personaid AND origen = var_origen;

        -- Se crea esta verificacion para ver si el estado del contrato aparece como enviado al gestor y se guarda en una variable --Emanuel
        SELECT enviado INTO var_resultado2 FROM contratos 
        WHERE iddocumento = p_piddocumento;

        IF var_resultado = 0 THEN
            var_paso_fecha := COALESCE(var_CDV_fechadocumento, var_CDV_FechaInicio);

            INSERT INTO g_documentosinfo(
                tipodocumentoid, empleadoid, empresaid, centrocostoid, lugarpagoid1, departamentoid,
                divisionid, quintonivelid, fechadocumento, fechacreacion, fechatermino, NumeroContrato,
                NombreArchivo, idS3, Origen)
            VALUES (
                var_CDV_idTipoGestor, var_CDV_Rut, var_em, var_cc, var_lp, var_dep, var_div, var_quintonivel,
                var_paso_fecha, CURRENT_DATE, var_CDV_FechaTermino, var_CDV_idDocumento,
                var_nombrearchivo, var_idS3, var_origen);

            SELECT currval(pg_get_serial_sequence('g_documentosinfo','documentoid')) INTO var_iddoc;
            -- Actualización del estado del contrato a enviado al gestor -- Emanuel
            UPDATE contratos
            SET enviado = true
            WHERE iddocumento = var_CDV_idDocumento;
        ELSE
            var_error := 1;
            var_mensaje := 'El Documento ya fue Enviado al Gestor';
            -- Se verifica que el estado del contrato aparece como enviado al gestor, si esta enviado devuelve su mensaje correspondiente-- Emanuel
            IF var_resultado2 THEN
                var_mensaje := var_mensaje || ' y se encuentra marcado como enviado.';
            ELSE
            -- Caso contrario, actualiza la tabla contratos y devuelve un mensaje corrigiendo su error.-- Emanuel
                UPDATE contratos
                SET enviado = true
                WHERE iddocumento = var_CDV_idDocumento;
                var_mensaje := var_mensaje || ' pero se ha corregido el estado a enviado en la base de datos.';
            END IF;
        END IF;

        IF (var_idS3 IS NULL OR var_idS3 = '') THEN
            var_error := 1;
            var_mensaje := 'No se encontró el ID de S3 para el documento';
            OPEN p_refcursor FOR SELECT var_error AS "error", var_mensaje AS "mensaje";
            RETURN p_refcursor;
        END IF;

    EXCEPTION WHEN OTHERS THEN
        var_error := 1;
        var_mensaje := SQLERRM;
    END;

    OPEN p_refcursor FOR SELECT var_error AS "error", COALESCE(var_mensaje, 'Documento enviado correctamente') AS "mensaje";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_subidadocumentos_generar(refcursor, character varying, character varying, integer, integer, integer, integer, integer, integer, integer, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_subidadocumentos_generar(refcursor, character varying, character varying, integer, integer, integer, integer, integer, integer, integer, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_subidadocumentos_generar(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_rutempresa character varying,
	p_idplantilla integer,
	p_idwf integer,
	p_idtipofirma integer,
	p_idtipogeneracion integer,
	p_idproceso integer,
	p_fila integer,
	p_tipocorreo integer,
	p_tipofirma integer,
	p_tipousuario integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_cursor ALIAS FOR p_refcursor;
    var_error integer := 0;
    var_mensaje text := '';
    var_iddocumento integer := 0;
    var_personaid varchar;
    var_rolid integer;
    var_region varchar;
    var_fono varchar;
    var_nombre varchar;
    var_nacionalidad varchar;
    var_correo varchar;
    var_correoinstitucional varchar;
    var_direccion varchar;
    var_comuna varchar;
    var_ciudad varchar;
    var_fechanacimiento date;
    var_estadocivil integer;
    var_largo integer;
    var_clave_temporal varchar;
    var_departamento varchar;
    var_lugarpago varchar;
    var_centrocosto varchar;
    var_division varchar;
    var_quintonivel varchar;
    v_niveles integer;
BEGIN
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    
    SELECT observaciones || ' ' || COALESCE(observaciones2, '')
    INTO var_mensaje
    FROM subidadocumentos
    WHERE usuarioid = p_usuarioid AND fila = p_fila;

    IF TRIM(var_mensaje) <> 'OK' THEN
        var_error := 1;
        var_iddocumento := 0;
        OPEN var_cursor FOR SELECT var_error AS "error", var_mensaje AS "mensaje", var_iddocumento AS "idDocumento";
        RETURN p_refcursor;
    END IF;

    BEGIN
        INSERT INTO contratos(
            idestado, idwf, fechacreacion, idtipofirma, idplantilla,
            doccode, eliminado, observacion, idproceso,
            enviado, idtipogeneracion, rutempresa
        ) VALUES (
            1, p_idwf, now(), p_idtipofirma, p_idplantilla,
            '', FALSE, '', p_idproceso, FALSE, p_idtipogeneracion, p_rutempresa
        ) RETURNING iddocumento INTO var_iddocumento;
    EXCEPTION WHEN OTHERS THEN
        var_error := 1;
        var_mensaje := SQLERRM;
        OPEN var_cursor FOR SELECT var_error AS "error", var_mensaje AS "mensaje", var_iddocumento AS "idDocumento";
        RETURN p_refcursor;
    END;

    -- Obtener niveles de subidadocumentos ANTES de los INSERTs
    IF v_niveles = 1 THEN
        SELECT lugarpagoid
        INTO var_lugarpago
        FROM subidadocumentos
        WHERE usuarioid = p_usuarioid AND fila = p_fila;
    ELSIF v_niveles = 2 THEN
        SELECT departamentoid, lugarpagoid
        INTO var_departamento, var_lugarpago
        FROM subidadocumentos
        WHERE usuarioid = p_usuarioid AND fila = p_fila;
    ELSIF v_niveles >= 3 THEN
        -- Para niveles 3-5, obtener de subidadocumentos si existen, sino de empleados
        SELECT 
            COALESCE(sd.departamentoid, e.departamentoid) as departamentoid,
            COALESCE(sd.lugarpagoid, e.lugarpagoid) as lugarpagoid,
            COALESCE(sd.centrocosto, e.centrocostoid) as centrocostoid,
            COALESCE(sd.divisionid, e.divisionid) as divisionid,
            COALESCE(sd.quintonivelid, e.quintonivelid) as quintonivelid
        INTO var_departamento, var_lugarpago, var_centrocosto, var_division, var_quintonivel
        FROM subidadocumentos sd
        LEFT JOIN empleados e ON e.empleadoid = sd.newusuarioid
        WHERE sd.usuarioid = p_usuarioid AND sd.fila = p_fila;
    END IF;

    BEGIN
        -- Insertar contratodatosvariables con niveles dinámicos
        IF v_niveles = 1 THEN
            INSERT INTO contratodatosvariables(
                iddocumento, rut, lugarpagoid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            )
            SELECT 
                var_iddocumento,
                REPLACE(LTRIM(REPLACE(UPPER(newusuarioid), '0', ' ')), ' ', '0'),
                lugarpagoid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            FROM subidadocumentos
            WHERE usuarioid = p_usuarioid AND fila = p_fila;
        ELSIF v_niveles = 2 THEN
            INSERT INTO contratodatosvariables(
                iddocumento, rut, lugarpagoid, departamentoid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            )
            SELECT 
                var_iddocumento,
                REPLACE(LTRIM(REPLACE(UPPER(newusuarioid), '0', ' ')), ' ', '0'),
                lugarpagoid, departamentoid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            FROM subidadocumentos
            WHERE usuarioid = p_usuarioid AND fila = p_fila;
        ELSIF v_niveles = 3 THEN
            INSERT INTO contratodatosvariables(
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            )
            SELECT 
                var_iddocumento,
                REPLACE(LTRIM(REPLACE(UPPER(newusuarioid), '0', ' ')), ' ', '0'),
                var_lugarpago, var_departamento, var_centrocosto, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            FROM subidadocumentos
            WHERE usuarioid = p_usuarioid AND fila = p_fila;
        ELSIF v_niveles = 4 THEN
            INSERT INTO contratodatosvariables(
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto, divisionid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            )
            SELECT 
                var_iddocumento,
                REPLACE(LTRIM(REPLACE(UPPER(newusuarioid), '0', ' ')), ' ', '0'),
                var_lugarpago, var_departamento, var_centrocosto, var_division, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            FROM subidadocumentos
            WHERE usuarioid = p_usuarioid AND fila = p_fila;
        ELSIF v_niveles = 5 THEN
            INSERT INTO contratodatosvariables(
                iddocumento, rut, lugarpagoid, departamentoid, centrocosto, divisionid, quintonivelid, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            )
            SELECT 
                var_iddocumento,
                REPLACE(LTRIM(REPLACE(UPPER(newusuarioid), '0', ' ')), ' ', '0'),
                var_lugarpago, var_departamento, var_centrocosto, var_division, var_quintonivel, fechadocumento,
                afp, banco, cargo, colacion, fechaingreso, fechainicio,
                fechatermino, horas, jornada, movilizacion, nombrecontactoemergencia,
                tipocuenta, nrocuenta, salud, sueldobase, bonotelefono,
                telefonocontactoemergencia, texto1, texto2, texto3, texto4,
                texto5, texto6, texto7, texto8, texto9, texto10, texto11,
                texto12, texto13, texto14, texto15, texto16, texto17, texto18,
                texto19, texto20, areafuncional
            FROM subidadocumentos
            WHERE usuarioid = p_usuarioid AND fila = p_fila;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        var_error := 1;
        var_mensaje := 'Error al insertar variables en el documento';
        OPEN var_cursor FOR SELECT var_error AS "error", var_mensaje AS "mensaje", var_iddocumento AS "idDocumento";
        RETURN p_refcursor;
    END;

    SELECT 
        newusuarioid, rolid, region, fono, nombre, nacionalidad,
        correo, correoinstitucional, direccion, comuna, ciudad,
        fechanacimiento, idestadocivil
    INTO
        var_personaid, var_rolid, var_region, var_fono, var_nombre, var_nacionalidad,
        var_correo, var_correoinstitucional, var_direccion, var_comuna, var_ciudad,
        var_fechanacimiento, var_estadocivil
    FROM subidadocumentos
    WHERE usuarioid = p_usuarioid AND fila = p_fila;

    SELECT parametro INTO var_largo FROM parametros WHERE idparametro = 'largoClaveMin';
    SELECT fncustompass(var_largo, 'CN') INTO var_clave_temporal;

    IF var_rolid <> 1 THEN
        var_rolid := 2;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE personaid = var_personaid) THEN
        INSERT INTO personas (
            personaid, nacionalidad, nombre, correo, correoinstitucional,
            direccion, comuna, ciudad, fechanacimiento, estadocivil,
            eliminado, fono, region
        ) VALUES (
            var_personaid, var_nacionalidad, var_nombre, var_correo, var_correoinstitucional,
            var_direccion, var_comuna, var_ciudad, var_fechanacimiento, var_estadocivil,
            FALSE, var_fono, var_region
        );
    ELSE
        UPDATE personas SET
            nombre = var_nombre,
            nacionalidad = var_nacionalidad,
            correo = var_correo,
            correoinstitucional = var_correoinstitucional,
            direccion = var_direccion,
            comuna = var_comuna,
            ciudad = var_ciudad,
            fechanacimiento = var_fechanacimiento,
            estadocivil = var_estadocivil,
            eliminado = FALSE,
            fono = var_fono,
            region = var_region
        WHERE personaid = var_personaid;
    END IF;


    IF NOT EXISTS (SELECT 1 FROM empleados WHERE empleadoid = var_personaid) THEN
        -- Insertar empleado con niveles dinámicos
        IF v_niveles = 1 THEN
            INSERT INTO empleados(empleadoid, rolid, idestadoempleado, rutempresa, lugarpagoid)
            VALUES (var_personaid, var_rolid, 'A', p_rutempresa, var_lugarpago);
        ELSIF v_niveles = 2 THEN
            INSERT INTO empleados(empleadoid, rolid, idestadoempleado, rutempresa, departamentoid, lugarpagoid)
            VALUES (var_personaid, var_rolid, 'A', p_rutempresa, var_departamento, var_lugarpago);
        ELSIF v_niveles = 3 THEN
            INSERT INTO empleados(empleadoid, rolid, idestadoempleado, rutempresa, departamentoid, lugarpagoid, centrocostoid)
            VALUES (var_personaid, var_rolid, 'A', p_rutempresa, var_departamento, var_lugarpago, var_centrocosto);
        ELSIF v_niveles = 4 THEN
            INSERT INTO empleados(empleadoid, rolid, idestadoempleado, rutempresa, departamentoid, lugarpagoid, centrocostoid, divisionid)
            VALUES (var_personaid, var_rolid, 'A', p_rutempresa, var_departamento, var_lugarpago, var_centrocosto, var_division);
        ELSIF v_niveles = 5 THEN
            INSERT INTO empleados(empleadoid, rolid, idestadoempleado, rutempresa, departamentoid, lugarpagoid, centrocostoid, divisionid, quintonivelid)
            VALUES (var_personaid, var_rolid, 'A', p_rutempresa, var_departamento, var_lugarpago, var_centrocosto, var_division, var_quintonivel);
        END IF;
    ELSE
        -- Actualizar empleado con niveles dinámicos
        IF v_niveles = 1 THEN
            UPDATE empleados SET
                rutempresa = p_rutempresa,
                lugarpagoid = var_lugarpago,
                rolid = var_rolid,
                idestadoempleado = 'A'
            WHERE empleadoid = var_personaid;
        ELSIF v_niveles = 2 THEN
            UPDATE empleados SET
                rutempresa = p_rutempresa,
                lugarpagoid = var_lugarpago,
                departamentoid = var_departamento,
                rolid = var_rolid,
                idestadoempleado = 'A'
            WHERE empleadoid = var_personaid;
        ELSIF v_niveles = 3 THEN
            UPDATE empleados SET
                rutempresa = p_rutempresa,
                lugarpagoid = var_lugarpago,
                departamentoid = var_departamento,
                centrocostoid = var_centrocosto,
                rolid = var_rolid,
                idestadoempleado = 'A'
            WHERE empleadoid = var_personaid;
        ELSIF v_niveles = 4 THEN
            UPDATE empleados SET
                rutempresa = p_rutempresa,
                lugarpagoid = var_lugarpago,
                departamentoid = var_departamento,
                centrocostoid = var_centrocosto,
                divisionid = var_division,
                rolid = var_rolid,
                idestadoempleado = 'A'
            WHERE empleadoid = var_personaid;
        ELSIF v_niveles = 5 THEN
            UPDATE empleados SET
                rutempresa = p_rutempresa,
                lugarpagoid = var_lugarpago,
                departamentoid = var_departamento,
                centrocostoid = var_centrocosto,
                divisionid = var_division,
                quintonivelid = var_quintonivel,
                rolid = var_rolid,
                idestadoempleado = 'A'
            WHERE empleadoid = var_personaid;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE usuarioid = var_personaid) THEN
        INSERT INTO usuarios (
            usuarioid, nombreusuario, clave, ultimavez, estado, bloqueado,
            cambiarclave, idfirma, loginexterno, tipousuarioid, rolid,
            clavetemporal, notifnuevousuario, rutempresa, idestadoempleado
        ) VALUES (
            var_personaid, '',
            encode(digest(var_clave_temporal, 'sha256'), 'hex'),
            now(), 1, 0, 1,
            p_tipofirma, 1, p_tipousuario,
            var_rolid, var_clave_temporal,
            1, p_rutempresa, 'A'
        );
    END IF;

    OPEN p_refcursor FOR
    SELECT 0 AS "error", '' AS "mensaje", var_iddocumento AS "idDocumento", var_personaid AS "personaid";
    RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_subidadocumentos_validacion(refcursor, character varying, character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_subidadocumentos_validacion(refcursor, character varying, character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_subidadocumentos_validacion(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_rutempresa character varying,
	p_idplantilla integer,
	p_idproceso integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
  v_error_msg TEXT;
  v_niveles INTEGER;
  v_nivel_activo BOOLEAN;
  v_nombre_nivel TEXT;
BEGIN
  -- Obtener la cantidad de niveles activos del cliente
  SELECT COUNT(*) INTO v_niveles
  FROM niveles_estructura
  WHERE activo = TRUE;

  UPDATE subidadocumentos
     SET estadosubida   = TRUE,
         observaciones2 = ''
   WHERE usuarioid = p_usuarioid;

  IF NOT EXISTS (SELECT 1 FROM plantillas WHERE idplantilla = p_idplantilla) THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | Plantilla no existe',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM procesos WHERE idproceso = p_idproceso) THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | Proceso no existe',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid;
  END IF;

  IF p_rutempresa = '' THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | RUT empresa vacío',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid;
  ELSIF NOT EXISTS (SELECT 1 FROM empresas WHERE rutempresa = p_rutempresa) THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | Empresa no existe',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid;
  END IF;

  -- Validación RUT empleado (siempre requerido)
  UPDATE subidadocumentos
     SET observaciones2 = COALESCE(observaciones2,'') || ' | RUT empleado vacío',
         estadosubida   = FALSE
   WHERE usuarioid = p_usuarioid
     AND (newusuarioid IS NULL OR newusuarioid = '')
     AND estadosubida;

  -- Validación dinámica de niveles según configuración del cliente
  -- Nivel 1: Lugares pago - siempre activo
  SELECT nombre INTO v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 1 AND activo = TRUE;
  
  UPDATE subidadocumentos
     SET observaciones2 = COALESCE(observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 1') || ' vacío',
         estadosubida   = FALSE
   WHERE usuarioid = p_usuarioid
     AND (lugarpagoid IS NULL OR lugarpagoid = '')
     AND estadosubida;

  -- Nivel 2: Departamentos - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 2 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 2') || ' vacío',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid
       AND (departamentoid IS NULL OR departamentoid = '')
       AND estadosubida;
  END IF;

  -- Nivel 3: Centro de Costo - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 3 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 3') || ' vacío',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid
       AND (centrocosto IS NULL OR centrocosto = '')
       AND estadosubida;
  END IF;

  -- Nivel 4: Division - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 4 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 4') || ' vacío',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid
       AND (divisionid IS NULL OR divisionid = '')
       AND estadosubida;
  END IF;

  -- Nivel 5: Quinto Nivel - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 5 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos
       SET observaciones2 = COALESCE(observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 5') || ' vacío',
           estadosubida   = FALSE
     WHERE usuarioid = p_usuarioid
       AND (quintonivelid IS NULL OR quintonivelid = '')
       AND estadosubida;
  END IF;

  -- Validaciones de pertenencia a empresa (solo para niveles activos)
  -- Nivel 1 siempre se valida
  SELECT nombre INTO v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 1 AND activo = TRUE;
  
  UPDATE subidadocumentos sd
     SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 1') || ' no pertenece a empresa',
         estadosubida   = FALSE
   WHERE sd.usuarioid = p_usuarioid
     AND sd.estadosubida
     AND NOT EXISTS (
       SELECT 1 FROM lugarespago lp
       WHERE lp.lugarpagoid = sd.lugarpagoid AND lp.empresaid::text = p_rutempresa
     );

  -- Nivel 2 - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 2 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos sd
       SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 2') || ' no pertenece a empresa',
           estadosubida   = FALSE
     WHERE sd.usuarioid = p_usuarioid
       AND sd.estadosubida
       AND NOT EXISTS (
         SELECT 1 FROM departamentos dep
         WHERE dep.lugarpagoid = sd.lugarpagoid
           AND dep.departamentoid = sd.departamentoid
           AND dep.empresaid::text = p_rutempresa
       );
  END IF;

  -- Nivel 3 - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 3 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos sd
       SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 3') || ' no pertenece a empresa',
           estadosubida   = FALSE
     WHERE sd.usuarioid = p_usuarioid
       AND sd.estadosubida
       AND NOT EXISTS (
         SELECT 1 FROM centroscosto cc
         WHERE cc.lugarpagoid = sd.lugarpagoid
           AND cc.departamentoid = sd.departamentoid
           AND cc.centrocostoid = sd.centrocosto
           AND cc.empresaid::text = p_rutempresa
       );
  END IF;

  -- Nivel 4 - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 4 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos sd
       SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 4') || ' no pertenece a empresa',
           estadosubida   = FALSE
     WHERE sd.usuarioid = p_usuarioid
       AND sd.estadosubida
       AND NOT EXISTS (
         SELECT 1 FROM division d
         WHERE d.lugarpagoid = sd.lugarpagoid
           AND d.departamentoid = sd.departamentoid
           AND d.centrocostoid = sd.centrocosto
           AND d.divisionid = sd.divisionid
           AND d.empresaid::text = p_rutempresa
       );
  END IF;

  -- Nivel 5 - validar solo si está activo
  SELECT activo, nombre INTO v_nivel_activo, v_nombre_nivel
  FROM niveles_estructura
  WHERE nivel = 5 AND activo = TRUE;

  IF v_nivel_activo THEN
    UPDATE subidadocumentos sd
       SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | ' || COALESCE(v_nombre_nivel, 'Nivel 5') || ' no pertenece a empresa',
           estadosubida   = FALSE
     WHERE sd.usuarioid = p_usuarioid
       AND sd.estadosubida
       AND NOT EXISTS (
         SELECT 1 FROM quinto_nivel qn
         WHERE qn.lugarpagoid = sd.lugarpagoid
           AND qn.departamentoid = sd.departamentoid
           AND qn.centrocostoid = sd.centrocosto
           AND qn.divisionid = sd.divisionid
           AND qn.quintonivelid = sd.quintonivelid
           AND qn.empresaid::text = p_rutempresa
       );
  END IF;

  -- Validaciones adicionales (estado civil, jornada, rol empleado)
  UPDATE subidadocumentos sd
     SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | Estado civil inválido',
         estadosubida   = FALSE
   WHERE sd.usuarioid = p_usuarioid
     AND sd.estadosubida
     AND NOT EXISTS (
       SELECT 1 FROM estadocivil ec
       WHERE ec.idestadocivil = sd.idestadocivil::integer
     );

  IF EXISTS (
    SELECT 1
      FROM plantillasclausulas pc
      JOIN clausulas c ON pc.idclausula = c.idclausula
     WHERE pc.idplantilla = p_idplantilla
       AND position('DATOS.Jornada' IN c.texto) > 0
  ) THEN
    UPDATE subidadocumentos sd
       SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | Jornada inválida',
           estadosubida   = FALSE
     WHERE sd.usuarioid = p_usuarioid
       AND sd.estadosubida
       AND NOT EXISTS (
         SELECT 1 FROM subclausulas sc
          WHERE sc.idsubclausula = sd.jornada::integer
            AND sc.idtiposubclausula = 2
       );
  END IF;

  UPDATE subidadocumentos sd
     SET observaciones2 = COALESCE(sd.observaciones2,'') || ' | Rol empleado inválido',
         estadosubida   = FALSE
   WHERE sd.usuarioid = p_usuarioid
     AND sd.estadosubida
     AND NOT EXISTS (
       SELECT 1 FROM roles r
        WHERE r.rolid = sd.rolid::integer
     );

  IF EXISTS (
    SELECT 1 FROM subidadocumentos
    WHERE usuarioid = p_usuarioid AND NOT estadosubida
  ) THEN
    SELECT STRING_AGG(observaciones2, ' | ') INTO v_error_msg
    FROM subidadocumentos
    WHERE usuarioid = p_usuarioid AND NOT estadosubida;

    OPEN p_refcursor FOR
    SELECT 1 AS "fila", 'ERROR' AS "resultado", v_error_msg AS "observaciones", 'ERROR' AS "tipo_transaccion";
    RETURN p_refcursor;
  END IF;

  OPEN p_refcursor FOR
    SELECT fila,
           'OK' AS "resultado",
           observaciones2 AS "observaciones",
           'OK' AS "tipo_transaccion",
           CASE WHEN estadosubida THEN 1 ELSE 0 END AS "estadoSubida"
    FROM subidadocumentos
    WHERE usuarioid = p_usuarioid
    ORDER BY fila;

  RETURN p_refcursor;
END;
$BODY$;


-- FUNCTION: public.sp_subidadocumentosvalida_insertar(refcursor, character varying, integer, timestamp without time zone, timestamp without time zone, date, character varying, character varying, character varying, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, date, date, date, character varying, character varying, integer, character varying, character varying, character varying, character varying, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, text, text, boolean, character varying)

-- DROP FUNCTION IF EXISTS public.sp_subidadocumentosvalida_insertar(refcursor, character varying, integer, timestamp without time zone, timestamp without time zone, date, character varying, character varying, character varying, date, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, date, date, date, character varying, character varying, integer, character varying, character varying, character varying, character varying, integer, integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, text, text, boolean, character varying);

CREATE OR REPLACE FUNCTION public.sp_subidadocumentosvalida_insertar(
	p_refcursor refcursor,
	p_usuarioid character varying,
	p_fila integer,
	p_fechacreacion timestamp without time zone,
	p_fechainsercion timestamp without time zone,
	p_fechadocumento date,
	p_newusuarioid character varying,
	p_nombre character varying,
	p_nacionalidad character varying,
	p_fechanacimiento date,
	p_idestadocivil character varying,
	p_direccion character varying,
	p_comuna character varying,
	p_ciudad character varying,
	p_region character varying,
	p_rolid character varying,
	p_correo character varying,
	p_correoinstitucional character varying,
	p_telefono character varying,
	p_lugarpagoid character varying,
	p_departamentoid character varying,
	p_centrocosto character varying,
	p_divisionid character varying,
	p_quintonivelid character varying,
	p_afp character varying,
	p_banco character varying,
	p_cargo character varying,
	p_colacion integer,
	p_fechaingreso date,
	p_fechainicio date,
	p_fechatermino date,
	p_horas character varying,
	p_jornada character varying,
	p_movilizacion integer,
	p_nombrecontactoemergencia character varying,
	p_tipocuenta character varying,
	p_nrocuenta character varying,
	p_salud character varying,
	p_sueldobase integer,
	p_bonotelefono integer,
	p_telefonocontactoemergencia character varying,
	p_texto1 character varying,
	p_texto2 character varying,
	p_texto3 character varying,
	p_texto4 character varying,
	p_texto5 character varying,
	p_texto6 character varying,
	p_texto7 character varying,
	p_texto8 character varying,
	p_texto9 character varying,
	p_texto10 character varying,
	p_texto11 character varying,
	p_texto12 character varying,
	p_texto13 character varying,
	p_texto14 character varying,
	p_texto15 character varying,
	p_texto16 character varying,
	p_texto17 character varying,
	p_texto18 character varying,
	p_texto19 character varying,
	p_texto20 character varying,
	p_areafuncional character varying,
	p_observaciones text,
	p_observaciones2 text,
	p_estadosubida boolean,
	p_idsubidadocumento character varying)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error integer := 0;
    var_mensaje text := NULL;
BEGIN
    BEGIN
        INSERT INTO subidadocumentos (
            usuarioid, fila, fechacreacion, fechainsercion, fechadocumento,
            newusuarioid, nombre, nacionalidad, fechanacimiento, idestadocivil,
            direccion, comuna, ciudad, region, rolid, correo, correoinstitucional,
            fono, lugarpagoid, departamentoid, centrocosto, divisionid, quintonivelid, afp, banco, cargo, colacion,
            fechaingreso, fechainicio, fechatermino, horas, jornada, movilizacion,
            nombrecontactoemergencia, tipocuenta, nrocuenta, salud, sueldobase,
            bonotelefono, telefonocontactoemergencia,
            texto1, texto2, texto3, texto4, texto5, texto6, texto7, texto8, texto9, texto10,
            texto11, texto12, texto13, texto14, texto15, texto16, texto17, texto18, texto19, texto20,
            areafuncional, observaciones, observaciones2, estadosubida, idsubidadocumento
        ) VALUES (
            p_usuarioid, p_fila, p_fechacreacion, p_fechainsercion, p_fechadocumento,
            p_newusuarioid, p_nombre, p_nacionalidad, p_fechanacimiento, p_idestadocivil,
            p_direccion, p_comuna, p_ciudad, p_region, p_rolid, p_correo, p_correoinstitucional,
            p_telefono, p_lugarpagoid, p_departamentoid, p_centrocosto, p_divisionid, p_quintonivelid, p_afp, p_banco, p_cargo, p_colacion,
            p_fechaingreso, p_fechainicio, p_fechatermino, p_horas, p_jornada, p_movilizacion,
            p_nombrecontactoemergencia, p_tipocuenta, p_nrocuenta, p_salud, p_sueldobase,
            p_bonotelefono, p_telefonocontactoemergencia,
            p_texto1, p_texto2, p_texto3, p_texto4, p_texto5, p_texto6, p_texto7, p_texto8, p_texto9, p_texto10,
            p_texto11, p_texto12, p_texto13, p_texto14, p_texto15, p_texto16, p_texto17, p_texto18, p_texto19, p_texto20,
            p_areafuncional, p_observaciones, p_observaciones2, p_estadosubida, p_idsubidadocumento
        );

        -- Si llega aquí, no hubo error
        var_mensaje := 'OK';
        
    EXCEPTION WHEN OTHERS THEN
        var_error := 1;
        var_mensaje := 'Error en INSERT: ' || SQLERRM;
    END;

    -- Resultado final del SP
    OPEN p_refcursor FOR
    SELECT
        1 AS "Fila",
        CASE WHEN var_error = 0 THEN 'OK' ELSE 'ERROR' END AS "Resultado",
        COALESCE(var_mensaje, 'Error desconocido') AS "Observaciones",
        CASE WHEN var_error = 0 THEN 'OK' ELSE 'ERROR' END AS "TipoTransaccion";

    RETURN p_refcursor;
END;
$BODY$;-- FUNCTION: public.sp_tiposusuarios_obtener_opciones(character varying, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_tiposusuarios_obtener_opciones(character varying, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_tiposusuarios_obtener_opciones(
	p_rfecursor character varying,
	p_ptipousuarioid integer,
	p_ptipousuarioingid integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    ref_cursor refcursor := p_rfecursor;
BEGIN
    OPEN ref_cursor FOR
        SELECT 
            OP_SIS.opcionid AS "opcionid",
            OP_SIS.nombre AS "nombre",
            OP_SIS.detalle AS "detalle",
            OP_TUC.consulta AS "consulta",
            OP_TUC.modifica AS "modifica",
            OP_TUC.crea AS "crea",
            OP_TUC.elimina AS "elimina",
            CASE WHEN OP_TUC.consulta = '1' THEN 'checked' ELSE '' END AS "checkconsulta",
            CASE WHEN OP_TUC.modifica = '1' THEN 'checked' ELSE '' END AS "checkmodifica",
            CASE WHEN OP_TUC.crea = '1' THEN 'checked' ELSE '' END AS "checkcrea",
            CASE WHEN OP_TUC.elimina = '1' THEN 'checked' ELSE '' END AS "checkelimina",
            CASE WHEN OP_TUC.ver = '1' THEN 'checked' ELSE '' END AS "checkver",
            CASE WHEN OP_TUI.consulta IS NULL OR OP_TUI.consulta = '0' THEN 'disabled' ELSE '' END AS "disabled_consulta",
            CASE WHEN OP_TUI.modifica IS NULL OR OP_TUI.modifica = '0' THEN 'disabled' ELSE '' END AS "disabled_modifica",
            CASE WHEN OP_TUI.crea IS NULL OR OP_TUI.crea = '0' THEN 'disabled' ELSE '' END AS "disabled_crea",
            CASE WHEN OP_TUI.elimina IS NULL OR OP_TUI.elimina = '0' THEN 'disabled' ELSE '' END AS "disabled_elimina",
            CASE WHEN OP_TUI.ver IS NULL OR OP_TUI.ver = '0' THEN 'disabled' ELSE '' END AS "disabled_ver"
        FROM opcionessistema AS OP_SIS
        LEFT JOIN opcionesxtipousuario AS OP_TUC
            ON OP_TUC.tipousuarioid = p_ptipousuarioid
            AND OP_TUC.opcionid = OP_SIS.opcionid
        LEFT JOIN opcionesxtipousuario AS OP_TUI
            ON OP_TUI.tipousuarioid = p_ptipousuarioingid
            AND OP_SIS.opcionid = OP_TUI.opcionid
        WHERE visible = true
        ORDER BY orden;
    RETURN p_rfecursor;
END;
$BODY$;


-- FUNCTION: public.sp_usuarios(refcursor, character, character varying, character, character varying, character, timestamp without time zone)

-- DROP FUNCTION IF EXISTS public.sp_usuarios(refcursor, character, character varying, character, character varying, character, timestamp without time zone);

CREATE OR REPLACE FUNCTION public.sp_usuarios(
	p_refcursor refcursor,
	p_accion character,
	p_usuarioid character varying,
	p_clave character,
	p_ip character varying,
	p_session character,
	p_ultimavez timestamp without time zone)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_xclave           char(100);
    var_cuantos          int;
    var_xcambiarclave    int;
    var_xbloqueado       int;
    var_intentosLogin    int;
    var_intentosLoginMax int;
    var_deshabilitado    int;
    var_error            int;
    var_mensaje          varchar(100);
    var_topeInactividad  int;
BEGIN
    IF p_accion = 'agregar' THEN
        IF NOT EXISTS (SELECT usuarioid FROM usuarios WHERE usuarioid = p_usuarioid) THEN
            INSERT INTO usuarios(usuarioid, clave, ip, sesion, ultimavez)
            VALUES (p_usuarioid, p_clave, p_ip, p_session, p_ultimavez);
            var_error := 0;
            var_mensaje := '';
        ELSE
            var_mensaje := 'El usuario ya fué ingresado';
            var_error := 1;
        END IF;
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'modificar' THEN
        UPDATE usuarios
           SET usuarioid = p_usuarioid,
               clave = p_clave,
               ip = p_ip,
               sesion = p_session,
               ultimavez = p_ultimavez
         WHERE usuarioid = p_usuarioid;
        var_error := 0;
        var_mensaje := '';
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'eliminar' THEN
        DELETE FROM usuarios WHERE usuarioid = p_usuarioid;
        var_error := 0;
        var_mensaje := '';
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'obtener' THEN
        OPEN p_refcursor FOR
            SELECT 
                u.usuarioid   AS "usuarioid",
                u.clave       AS "clave",
                u.ip          AS "ip",
                u.sesion      AS "sesion",
                u.ultimavez   AS "ultimavez",
                per.nombre    AS "nombre",
				u.bloqueado,
				u.deshabilitado
            FROM usuarios u
            LEFT JOIN personas per ON u.usuarioid = per.personaid
            WHERE u.usuarioid = p_usuarioid;
        RETURN p_refcursor;
    
    ELSIF p_accion = 'agregarSesion' THEN
        UPDATE usuarios
           SET sesion = p_session,
               ip = p_ip,
               ultimavez = now()
         WHERE usuarioid = p_usuarioid;
        var_error := 0;
        var_mensaje := '';
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'actualizarSesion' THEN
        UPDATE usuarios
           SET ultimavez = now()
         WHERE sesion = p_session AND usuarioid = p_usuarioid;
        var_error := 0;
        var_mensaje := '';
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'eliminarSesion' THEN
        UPDATE usuarios
           SET sesion = ''
         WHERE sesion = p_session AND usuarioid = p_usuarioid;
        var_error := 0;
        var_mensaje := '';
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSIF p_accion = 'verificarSesion' THEN
        OPEN p_refcursor FOR
            SELECT 
                u.usuarioid   AS "usuarioid",
                u.ip          AS "ip",
                u.ultimavez   AS "ultimavez",
                COALESCE(per.nombre, '') || ' ' || COALESCE(per.appaterno, '') || ' ' || COALESCE(per.apmaterno, '') AS "nombre",
                u.cambiarclave AS "cambiarclave",
                u.bloqueado    AS "bloqueado",
                per.correo     AS "correo",
                u.tipousuarioid AS "tipousuarioid",
                now()         AS "fechaactual",
                tu.nombre     AS "nombreperfil"
            FROM usuarios u
            INNER JOIN personas per ON per.personaid = u.usuarioid
            LEFT JOIN tiposusuarios tu ON u.tipousuarioid = tu.tipousuarioid
            WHERE u.sesion = p_session
              AND u.usuarioid = p_usuarioid
            GROUP BY u.usuarioid, u.ip, u.ultimavez, per.nombre, per.appaterno, per.apmaterno,
                     u.cambiarclave, u.bloqueado, per.correo, u.tipousuarioid, tu.nombre;
        RETURN p_refcursor;
    
    ELSIF p_accion = 'obtenerContrasena' THEN
        var_mensaje := '';
        var_error := 0;
        IF NOT EXISTS (SELECT clave FROM usuarios WHERE usuarioid = p_usuarioid) THEN
            var_mensaje := 'Usuario o Contraseña incorrecta';
            var_error := 1;
        ELSE
            IF p_clave = '' OR p_clave IS NULL THEN
                var_mensaje := 'Debe ingresar contraseña';
                var_error := 1;
            ELSE
                SELECT parametro::int INTO var_topeInactividad
                  FROM parametros
                 WHERE idparametro = 'topeInactividad';
    
                UPDATE usuarios
                   SET deshabilitado = 1
                 WHERE usuarioid IN (
                    SELECT CASE 
                             WHEN EXTRACT(day FROM (now() - ultimavez)) > var_topeInactividad 
                             THEN usuarioid 
                             ELSE NULL 
                           END
                      FROM usuarios
                      WHERE usuarioid = p_usuarioid
                 );
    
                SELECT clave, cambiarclave, bloqueado, intentoslogin, deshabilitado
                  INTO var_xclave, var_xcambiarclave, var_xbloqueado, var_intentosLogin, var_deshabilitado
                  FROM usuarios
                  WHERE usuarioid = p_usuarioid;
    
                IF COALESCE(var_deshabilitado, 0) <> 1 THEN
                    IF p_clave <> var_xclave THEN
                        IF var_intentosLogin IS NULL THEN
                            UPDATE usuarios SET intentoslogin = 1 WHERE usuarioid = p_usuarioid;
                        ELSE
                            UPDATE usuarios SET intentoslogin = intentoslogin + 1 WHERE usuarioid = p_usuarioid;
                        END IF;
                        SELECT intentoslogin INTO var_intentosLogin FROM usuarios WHERE usuarioid = p_usuarioid;
                        SELECT parametro::int INTO var_intentosLoginMax
                          FROM parametros
                          WHERE idparametro = 'intentosLogin';
                        IF var_intentosLogin >= var_intentosLoginMax THEN
                            UPDATE usuarios SET bloqueado = 1 WHERE usuarioid = p_usuarioid;
                            INSERT INTO enviocorreos(codcorreo, rutusuario, tipocorreo)
                            VALUES (14, p_usuarioid, 1);
                            var_mensaje := 'Usuario bloqueado';
                            var_error := 1;
                        ELSE
                            var_mensaje := 'Usuario o Contraseña incorrecta';
                            var_error := 1;
                        END IF;
                    ELSE
                        IF var_xbloqueado = 1 THEN
                            var_mensaje := 'Usuario bloqueado';
                            var_error := 1;
                        ELSIF var_xcambiarclave = 1 THEN
                            var_mensaje := 'Debe cambiar su contraseña para continuar';
                            var_error := 2;
                        ELSE
                            UPDATE usuarios SET intentoslogin = NULL WHERE usuarioid = p_usuarioid;
                        END IF;
                    END IF;
                ELSE
                    var_mensaje := 'Cuenta deshabilitada';
                    var_error := 1;
                END IF;
            END IF;
        END IF;
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    
    ELSE
        var_mensaje := 'Acción no reconocida';
        var_error := 1;
        OPEN p_refcursor FOR 
            SELECT var_error AS "error", var_mensaje AS "mensaje";
        RETURN p_refcursor;
    END IF;
END;
$BODY$;


-- FUNCTION: public.sp_validaciones_listado(refcursor, text, integer, date, date, text, integer, integer, text, integer, integer)

-- DROP FUNCTION IF EXISTS public.sp_validaciones_listado(refcursor, text, integer, date, date, text, integer, integer, text, integer, integer);

CREATE OR REPLACE FUNCTION public.sp_validaciones_listado(
	p_refcursor refcursor,
	p_accion text,
	p_tipousuarioid integer,
	p_fecha_creacion_desde date,
	p_fecha_creacion_hasta date,
	p_empleadoid text,
	p_tipodocumentoidsel integer,
	p_documentoid integer,
	p_usuarioid text,
	p_pagina integer,
	p_decuantos integer)
    RETURNS refcursor
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    var_error INTEGER;
    var_mensaje VARCHAR(100);
    var_totalreg NUMERIC(9,2);
    var_vdecimal NUMERIC(9,2);
    var_total INTEGER;
    var_totalreg2 INTEGER;
    var_rolid INTEGER;
    var_estado VARCHAR(1);
    var_rolempleado INTEGER;
    var_xfechadesde TIMESTAMP;
    var_xfechahasta TIMESTAMP;
    var_sql TEXT;
    var_count_sql TEXT;
    var_result RECORD;
    v_niveles INTEGER;
    var_log_message TEXT;
BEGIN
    -- Log de inicio de función
    var_log_message := 'INICIO sp_validaciones_listado - Parámetros: accion=' || COALESCE(p_accion, 'NULL') || 
                      ', tipousuarioid=' || COALESCE(p_tipousuarioid::TEXT, 'NULL') || 
                      ', empleadoid=' || COALESCE(p_empleadoid, 'NULL') || 
                      ', usuarioid=' || COALESCE(p_usuarioid, 'NULL');
    RAISE NOTICE '%', var_log_message;
    
    -- Obtener niveles dinámicamente
    SELECT public.CONSULTAR_NIVELES() INTO v_niveles;
    RAISE NOTICE 'Niveles disponibles: %', v_niveles;
    
    -- Preparar fechas
    IF p_fecha_creacion_desde IS NOT NULL THEN
        var_xfechadesde := p_fecha_creacion_desde::DATE || ' 00:00:00';
    END IF;
    
    IF p_fecha_creacion_hasta IS NOT NULL THEN
        var_xfechahasta := p_fecha_creacion_hasta::DATE || ' 23:59:59.99';
    END IF;
    
    
    -- Construir consulta base
    var_sql := '
        SELECT 
            DOC.documentoid,
            DOC.tipodocumentoid,
            TD.nombre AS nombredocumento,
            DOC.empleadoid,
            COALESCE(PER.nombre, '''') || '' '' || COALESCE(PER.appaterno, '''') || '' '' || COALESCE(PER.apmaterno, '''') AS nombre,
            DOC.empresaid,
            EMP.RazonSocial AS nombreempresa,
            TO_CHAR(DOC.fechadocumento, ''DD-MM-YYYY'') AS fechadocumento,
            TO_CHAR(DOC.fechacreacion, ''DD-MM-YYYY'') AS fechacreacion,
            TO_CHAR(DOC.fechatermino, ''DD-MM-YYYY'') AS fechatermino,
            ROW_NUMBER() OVER(ORDER BY DOC.fechadocumento) AS rownum,
            CASE 
                WHEN COALESCE(DOC.NumeroContrato, 0) > 0 
                THEN DOC.NumeroContrato::TEXT
                ELSE ''0''
            END AS nrocontrato';
    
    -- Agregar campos de niveles dinámicamente (solo si están disponibles)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || ', LP.nombrelugarpago';
        RAISE NOTICE 'Agregando campo nivel 1: nombrelugarpago';
    END IF;
    IF v_niveles >= 2 THEN
        var_sql := var_sql || ', DP.nombredepartamento';
        RAISE NOTICE 'Agregando campo nivel 2: nombredepartamento';
    END IF;
    IF v_niveles >= 3 THEN
        var_sql := var_sql || ', CCO.nombrecentrocosto';
        RAISE NOTICE 'Agregando campo nivel 3: nombrecentrocosto';
    END IF;
    IF v_niveles >= 4 THEN
        var_sql := var_sql || ', DIV.nombredivision';
        RAISE NOTICE 'Agregando campo nivel 4: nombredivision';
    END IF;
    IF v_niveles = 5 THEN
        var_sql := var_sql || ', QN.nombrequintonivel';
        RAISE NOTICE 'Agregando campo nivel 5: nombrequintonivel';
    END IF;
    
    -- FROM y JOINs base (mantener estructura existente)
    var_sql := var_sql || '
        FROM g_documentosinfo AS DOC
        INNER JOIN tipogestor AS TD ON TD.idtipogestor = DOC.tipodocumentoid
        INNER JOIN g_tiposdocumentosxperfil ON g_tiposdocumentosxperfil.tipodocumentoid = DOC.tipodocumentoid
            AND g_tiposdocumentosxperfil.tipousuarioid = ' || p_tipousuarioid || '
        INNER JOIN empleados AS EMPL ON EMPL.empleadoid = DOC.empleadoid
        INNER JOIN personas AS PER ON PER.personaid = DOC.empleadoid
        INNER JOIN empresas AS EMP ON EMP.rutempresa = DOC.empresaid';
    
    -- JOINs de niveles dinámicos (solo agregar los que están disponibles)
    IF v_niveles >= 1 THEN
        var_sql := var_sql || '
        INNER JOIN lugarespago AS LP ON LP.lugarpagoid = EMPL.lugarpagoid
            AND LP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 1: lugarespago';
    END IF;

    IF v_niveles >= 2 THEN
        var_sql := var_sql || '
        INNER JOIN departamentos AS DP ON DP.departamentoid = EMPL.departamentoid
            AND DP.lugarpagoid = EMPL.lugarpagoid
            AND DP.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 2: departamentos';
    END IF;

    IF v_niveles >= 3 THEN
        var_sql := var_sql || '
        INNER JOIN centroscosto AS CCO ON CCO.centrocostoid = EMPL.centrocostoid
            AND CCO.lugarpagoid = EMPL.lugarpagoid
            AND CCO.departamentoid = EMPL.departamentoid
            AND CCO.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 3: centroscosto';
    END IF;

    IF v_niveles >= 4 THEN
        var_sql := var_sql || '
        INNER JOIN division AS DIV ON DIV.divisionid = EMPL.divisionid
            AND DIV.lugarpagoid = EMPL.lugarpagoid
            AND DIV.departamentoid = EMPL.departamentoid
            AND DIV.centrocostoid = EMPL.centrocostoid
            AND DIV.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 4: division';
    END IF;

    IF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN quinto_nivel AS QN ON QN.quintonivelid = EMPL.quintonivelid
            AND QN.lugarpagoid = EMPL.lugarpagoid
            AND QN.departamentoid = EMPL.departamentoid
            AND QN.centrocostoid = EMPL.centrocostoid
            AND QN.divisionid = EMPL.divisionid
            AND QN.empresaid = EMPL.rutempresa';
        RAISE NOTICE 'Agregando JOIN nivel 5: quinto_nivel';
    END IF;

    -- Obtener rol y estado del usuario para aplicar permisos
    SELECT COALESCE(rolid, 2), COALESCE(idEstadoEmpleado, 'A')
    INTO var_rolid, var_estado
    FROM usuarios
    WHERE usuarioid = p_usuarioid;
    
    RAISE NOTICE 'Usuario % - Rol: %, Estado: %', p_usuarioid, var_rolid, var_estado;
    
    -- Aplicar permisos según el nivel más alto disponible usando INNER JOIN
    RAISE NOTICE 'Aplicando permisos para nivel: %', v_niveles;

    IF v_niveles = 1 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariolugarespago ALP ON ALP.empresaid = DOC.empresaid
            AND ALP.lugarpagoid = EMPL.lugarpagoid
            AND ALP.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 1: g_accesoxusuariolugarespago';
    ELSIF v_niveles = 2 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodepartamento ADV ON ADV.empresaid = DOC.empresaid
            AND ADV.lugarpagoid = EMPL.lugarpagoid
            AND ADV.departamentoid = EMPL.departamentoid
            AND ADV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 2: g_accesoxusuariodepartamento';
    ELSIF v_niveles = 3 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioccosto ACC ON ACC.empresaid = DOC.empresaid
            AND ACC.lugarpagoid = EMPL.lugarpagoid
            AND ACC.departamentoid = EMPL.departamentoid
            AND ACC.centrocostoid = EMPL.centrocostoid
            AND ACC.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 3: g_accesoxusuarioccosto';
    ELSIF v_niveles = 4 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuariodivision ADIV ON ADIV.empresaid = DOC.empresaid
            AND ADIV.lugarpagoid = EMPL.lugarpagoid
            AND ADIV.departamentoid = EMPL.departamentoid
            AND ADIV.centrocostoid = EMPL.centrocostoid
            AND ADIV.divisionid = EMPL.divisionid
            AND ADIV.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 4: g_accesoxusuariodivision';
    ELSIF v_niveles = 5 THEN
        var_sql := var_sql || '
        INNER JOIN g_accesoxusuarioquintonivel AQN ON AQN.empresaid = DOC.empresaid
            AND AQN.lugarpagoid = EMPL.lugarpagoid
            AND AQN.departamentoid = EMPL.departamentoid
            AND AQN.centrocostoid = EMPL.centrocostoid
            AND AQN.divisionid = EMPL.divisionid
            AND AQN.quintonivelid = EMPL.quintonivelid
            AND AQN.usuarioid = ' || quote_literal(p_usuarioid);
        RAISE NOTICE 'Agregando JOIN de permisos nivel 5: g_accesoxusuarioquintonivel';
    END IF;

    var_sql := var_sql || '
        WHERE 1=1';
    
    -- Agregar condiciones de fecha
    IF p_fecha_creacion_desde IS NOT NULL AND p_fecha_creacion_hasta IS NOT NULL THEN
        var_sql := var_sql || ' AND DOC.fechadocumento BETWEEN ''' || var_xfechadesde || ''' AND ''' || var_xfechahasta || '''';
        RAISE NOTICE 'Agregando filtro de fechas: % a %', var_xfechadesde, var_xfechahasta;
    END IF;
    
    -- Agregar condiciones de filtro
    IF p_empleadoid != '' THEN
        var_sql := var_sql || ' AND DOC.empleadoid = ''' || p_empleadoid || '''';
        RAISE NOTICE 'Agregando filtro empleadoid: %', p_empleadoid;
    END IF;
    
    IF p_tipodocumentoidsel != 0 THEN
        var_sql := var_sql || ' AND DOC.tipodocumentoid = ' || p_tipodocumentoidsel;
        RAISE NOTICE 'Agregando filtro tipodocumentoid: %', p_tipodocumentoidsel;
    END IF;
    
    IF p_documentoid != 0 THEN
        var_sql := var_sql || ' AND DOC.documentoid = ' || p_documentoid;
        RAISE NOTICE 'Agregando filtro documentoid: %', p_documentoid;
    END IF;
    
    -- Agregar condición de contrato
    var_sql := var_sql || ' AND COALESCE(DOC.NumeroContrato, 0) = 0';
    RAISE NOTICE 'Agregando filtro: solo documentos sin contrato';
    
    -- Aplicar filtros de rol y estado según los casos originales
    RAISE NOTICE 'Evaluando casos - Rol: %, Estado: %', var_rolid, var_estado;
    
    IF var_rolid = 1 AND var_estado = 'F' THEN
        -- Caso 1: Puede ver todos los roles y puede ver finiquitados
        RAISE NOTICE 'Caso 1: Rol privado + Estado finiquitado - Sin filtros adicionales';
        -- NO agregar filtros de rol ni estado (puede ver todo)
    ELSIF var_rolid != 1 AND var_estado = 'F' THEN
        -- Caso 2: No puede ver rol privado, pero sí puede ver finiquitados
        RAISE NOTICE 'Caso 2: Rol público + Estado finiquitado - Excluyendo rol privado';
        var_sql := var_sql || ' AND COALESCE(EMPL.rolid, 2) <> 1';
    ELSIF var_rolid = 1 AND var_estado = 'A' THEN
        -- Caso 3: Puede ver rol privado, pero no puede ver finiquitados
        RAISE NOTICE 'Caso 3: Rol privado + Estado activo - Excluyendo finiquitados';
        var_sql := var_sql || ' AND COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E''';
    ELSIF var_rolid = 2 AND var_estado = 'A' THEN
        -- Caso 4: No puede ver rol privado, y no puede ver finiquitados
        RAISE NOTICE 'Caso 4: Rol público + Estado activo - Excluyendo rol privado y finiquitados';
        var_sql := var_sql || ' AND COALESCE(EMPL.rolid, 2) <> 1';
        var_sql := var_sql || ' AND COALESCE(EMPL.idEstadoEmpleado, ''A'') <> ''E''';
    ELSE
        RAISE NOTICE 'Caso no contemplado - Rol: %, Estado: %', var_rolid, var_estado;
    END IF;
    
    -- Log de la consulta SQL final
    RAISE NOTICE 'Consulta SQL final construida (primeros 500 caracteres): %', LEFT(var_sql, 500);
    RAISE NOTICE 'Consulta SQL completa: %', var_sql;
    
    -- Manejar acción Total
    IF p_accion = 'Total' THEN
        RAISE NOTICE 'Procesando acción: Total';
        -- Crear consulta de conteo
        var_count_sql := 'SELECT COUNT(*) FROM (' || var_sql || ') AS subquery';
        RAISE NOTICE 'Ejecutando consulta de conteo';
        
        EXECUTE var_count_sql INTO var_totalreg2;
        RAISE NOTICE 'Total de registros encontrados: %', var_totalreg2;
        
        -- Calcular total de páginas
        IF var_totalreg2 = 0 THEN
            var_total := 0;
        ELSE
            -- Forzar división decimal convirtiendo a NUMERIC
            var_totalreg := var_totalreg2::NUMERIC / p_decuantos;
            var_vdecimal := var_totalreg - FLOOR(var_totalreg);
            
            IF var_vdecimal > 0 THEN
                var_total := CEIL(var_totalreg);
            ELSE
                var_total := FLOOR(var_totalreg);
            END IF;
        END IF;
        
        RAISE NOTICE 'Total de páginas calculado: %', var_total;
        RAISE NOTICE 'Total de registros: %', var_totalreg2;
        RAISE NOTICE 'Devolviendo: total=%, totalreg=%', var_total, var_totalreg2;
        
        -- Abrir cursor con el total de páginas y total de registros
        OPEN p_refcursor FOR SELECT var_total::INTEGER AS total, var_totalreg2::INTEGER AS totalreg;
        RETURN p_refcursor;
    END IF;
    
    -- Manejar acción Listado
    IF p_accion = 'Listado' THEN
        RAISE NOTICE 'Procesando acción: Listado - Página: %, Registros por página: %', p_pagina, p_decuantos;
        -- Agregar paginación
        var_sql := 'SELECT * FROM (' || var_sql || ') AS ResultadoPaginado 
                   WHERE rownum BETWEEN ' || ((p_pagina - 1) * p_decuantos + 1) || 
                   ' AND ' || (p_pagina * p_decuantos);
        
        RAISE NOTICE 'Ejecutando consulta de listado con paginación';
        
        -- Abrir cursor con los resultados
        OPEN p_refcursor FOR EXECUTE var_sql;
        RETURN p_refcursor;
    END IF;
    
    -- Si no es una acción válida, retornar error
    RAISE NOTICE 'Acción no válida recibida: %', p_accion;
    RAISE EXCEPTION 'Acción no válida: %', p_accion;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR en sp_validaciones_listado: %', SQLERRM;
        RAISE EXCEPTION 'Error en sp_validaciones_listado: %', SQLERRM;
END;
$BODY$;


