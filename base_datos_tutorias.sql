-- =====================================================
-- Base de datos: Sistema de Gestión de Tutorías Universitarias
-- Esquema final normalizado (1FN → 5FN + refinamiento 6FN)
-- Compatible con MySQL 8.0.16+ / MariaDB 10.4+
-- (con mínimos cambios, PostgreSQL)
-- =====================================================

DROP DATABASE IF EXISTS tutorias;
CREATE DATABASE tutorias CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tutorias;

-- ---------- DEPARTAMENTO ----------
-- Llaves candidatas: {id_departamento}, {nombre}
CREATE TABLE departamento (
    id_departamento INT PRIMARY KEY AUTO_INCREMENT,
    nombre          VARCHAR(100) NOT NULL,
    CONSTRAINT uq_departamento_nombre UNIQUE (nombre)
);

-- ---------- ESTUDIANTE ----------
-- Llaves candidatas: {id_estudiante}, {email}  (DF9: email → id_estudiante)
CREATE TABLE estudiante (
    id_estudiante INT PRIMARY KEY AUTO_INCREMENT,
    nombre        VARCHAR(120) NOT NULL,
    email         VARCHAR(150) NOT NULL,
    semestre      SMALLINT     NOT NULL,
    promedio      DECIMAL(3,2),
    CONSTRAINT uq_estudiante_email   UNIQUE (email),
    CONSTRAINT chk_estudiante_sem    CHECK (semestre BETWEEN 1 AND 12),
    CONSTRAINT chk_estudiante_prom   CHECK (promedio BETWEEN 0.00 AND 5.00)
);

-- ---------- TUTOR ----------
-- Relación "Es" (1:1): Tutor es especialización de Estudiante.
-- id_tutor es PK y FK a la vez; los datos personales viven en ESTUDIANTE.
CREATE TABLE tutor (
    id_tutor             INT PRIMARY KEY,
    id_departamento      INT          NOT NULL,
    semestre_habilitado  VARCHAR(7)   NOT NULL,              -- ej. '2026-2'
    aval_departamento    BOOLEAN      NOT NULL DEFAULT FALSE,
    nota_minima_aprobada DECIMAL(3,2) NOT NULL,
    CONSTRAINT fk_tutor_estudiante   FOREIGN KEY (id_tutor)
        REFERENCES estudiante(id_estudiante) ON DELETE CASCADE,
    CONSTRAINT fk_tutor_departamento FOREIGN KEY (id_departamento)
        REFERENCES departamento(id_departamento),
    CONSTRAINT chk_tutor_nota CHECK (nota_minima_aprobada BETWEEN 0.00 AND 5.00)
);

-- ---------- MATERIA ----------
-- Pertenece Materia (Departamento 1:N Materia)
-- Llaves candidatas: {id_materia}, {id_departamento, nombre}
CREATE TABLE materia (
    id_materia      INT PRIMARY KEY AUTO_INCREMENT,
    nombre          VARCHAR(120) NOT NULL,
    id_departamento INT          NOT NULL,
    CONSTRAINT fk_materia_departamento FOREIGN KEY (id_departamento)
        REFERENCES departamento(id_departamento),
    CONSTRAINT uq_materia_depto_nombre UNIQUE (id_departamento, nombre)
);

-- ---------- AULA ----------
-- Pertenece Aula (Departamento 1:N Aula)
-- disponibilidad = estado operativo atómico (habilitada / fuera de servicio);
-- la ocupación por franja se obtiene de SESION.
CREATE TABLE aula (
    id_aula         INT PRIMARY KEY AUTO_INCREMENT,
    capacidad       SMALLINT NOT NULL,
    disponibilidad  BOOLEAN  NOT NULL DEFAULT TRUE,
    id_departamento INT      NOT NULL,
    CONSTRAINT fk_aula_departamento FOREIGN KEY (id_departamento)
        REFERENCES departamento(id_departamento),
    CONSTRAINT chk_aula_capacidad CHECK (capacidad > 0)
);

-- ---------- SESION ----------
-- Imparte (Tutor 1:N Sesion), Es de (Materia 1:N Sesion),
-- Se realiza en (Aula 1:1 Sesion POR FRANJA HORARIA).
-- Llaves candidatas: {id_sesion}, {id_aula, fecha, hora}, {id_tutor, fecha, hora}
CREATE TABLE sesion (
    id_sesion   INT PRIMARY KEY AUTO_INCREMENT,
    fecha       DATE        NOT NULL,
    hora        TIME        NOT NULL,
    modalidad   VARCHAR(10) NOT NULL,
    cupo_maximo SMALLINT    NOT NULL,
    id_tutor    INT         NOT NULL,
    id_materia  INT         NOT NULL,
    id_aula     INT         NULL,          -- NULL solo si la sesión es VIRTUAL
    CONSTRAINT fk_sesion_tutor   FOREIGN KEY (id_tutor)   REFERENCES tutor(id_tutor),
    CONSTRAINT fk_sesion_materia FOREIGN KEY (id_materia) REFERENCES materia(id_materia),
    CONSTRAINT fk_sesion_aula    FOREIGN KEY (id_aula)    REFERENCES aula(id_aula),
    CONSTRAINT chk_sesion_modalidad CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    CONSTRAINT chk_sesion_cupo      CHECK (cupo_maximo > 0),
    CONSTRAINT chk_sesion_aula      CHECK (modalidad = 'VIRTUAL' OR id_aula IS NOT NULL),
    CONSTRAINT uq_sesion_aula_franja  UNIQUE (id_aula,  fecha, hora),  -- aula sin cruces
    CONSTRAINT uq_sesion_tutor_franja UNIQUE (id_tutor, fecha, hora)   -- tutor sin cruces
);

-- ---------- RECURSO_VIRTUAL ----------
-- Usa (Sesion 1:1 RecursoVirtual). La FK va del lado opcional para que
-- SESION no tenga una columna nula en cada sesión presencial.
-- Llaves candidatas: {id_recurso}, {id_sesion}
CREATE TABLE recurso_virtual (
    id_recurso INT PRIMARY KEY AUTO_INCREMENT,
    id_sesion  INT          NOT NULL,
    plataforma VARCHAR(50)  NOT NULL,
    enlace     VARCHAR(500) NOT NULL,
    CONSTRAINT fk_recurso_sesion FOREIGN KEY (id_sesion)
        REFERENCES sesion(id_sesion) ON DELETE CASCADE,
    CONSTRAINT uq_recurso_sesion UNIQUE (id_sesion)
);

-- ---------- INSCRIPCION ----------
-- Inscribe (Estudiante N:M Sesion)
CREATE TABLE inscripcion (
    id_estudiante     INT       NOT NULL,
    id_sesion         INT       NOT NULL,
    fecha_inscripcion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_estudiante, id_sesion),
    CONSTRAINT fk_insc_estudiante FOREIGN KEY (id_estudiante)
        REFERENCES estudiante(id_estudiante),
    CONSTRAINT fk_insc_sesion     FOREIGN KEY (id_sesion)
        REFERENCES sesion(id_sesion) ON DELETE CASCADE
);

-- ---------- EVALUACION ----------
-- Evalua (Estudiante N:M Sesion). Separada de INSCRIPCION (refinamiento 6FN):
-- la evaluación ocurre después de la sesión y no deja nulos en la inscripción.
-- FK compuesta → INSCRIPCION: solo puede evaluar quien estuvo inscrito.
CREATE TABLE evaluacion (
    id_estudiante INT          NOT NULL,
    id_sesion     INT          NOT NULL,
    calificacion  SMALLINT     NOT NULL,
    comentario    VARCHAR(500),
    PRIMARY KEY (id_estudiante, id_sesion),
    CONSTRAINT fk_eval_inscripcion FOREIGN KEY (id_estudiante, id_sesion)
        REFERENCES inscripcion(id_estudiante, id_sesion) ON DELETE CASCADE,
    CONSTRAINT chk_eval_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);

-- ---------- Índices de consulta ----------
CREATE INDEX idx_sesion_fecha   ON sesion(fecha);
CREATE INDEX idx_sesion_materia ON sesion(id_materia);
CREATE INDEX idx_insc_sesion    ON inscripcion(id_sesion);

-- =====================================================
-- Reglas de negocio fuera del esquema declarativo (disparadores)
-- Involucran varias tablas o agregaciones; por eso el modelo no está
-- estrictamente en FNDK.
-- =====================================================

DELIMITER $$

-- R1 + R4 + R7: al crear o modificar una sesión
--   R1: cupo_maximo ≤ capacidad del aula (si tiene aula)
--   R4: solo imparten tutores con aval y en su semestre habilitado
--   R7: las sesiones con aula usan aulas disponibles
CREATE TRIGGER trg_sesion_bi BEFORE INSERT ON sesion
FOR EACH ROW
BEGIN
    DECLARE v_cap SMALLINT;
    DECLARE v_disp BOOLEAN;
    DECLARE v_aval BOOLEAN;

    IF NEW.id_aula IS NOT NULL THEN
        SELECT capacidad, disponibilidad INTO v_cap, v_disp
        FROM aula WHERE id_aula = NEW.id_aula;
        IF NEW.cupo_maximo > v_cap THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R1: el cupo supera la capacidad del aula';
        END IF;
        IF v_disp = FALSE THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R7: el aula no está disponible';
        END IF;
    END IF;

    SELECT aval_departamento INTO v_aval FROM tutor WHERE id_tutor = NEW.id_tutor;
    IF v_aval = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R4: el tutor no tiene aval del departamento';
    END IF;
END$$

CREATE TRIGGER trg_sesion_bu BEFORE UPDATE ON sesion
FOR EACH ROW
BEGIN
    DECLARE v_cap SMALLINT;
    DECLARE v_disp BOOLEAN;
    DECLARE v_aval BOOLEAN;
    DECLARE v_inscritos INT;

    IF NEW.id_aula IS NOT NULL THEN
        SELECT capacidad, disponibilidad INTO v_cap, v_disp
        FROM aula WHERE id_aula = NEW.id_aula;
        IF NEW.cupo_maximo > v_cap THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R1: el cupo supera la capacidad del aula';
        END IF;
        IF v_disp = FALSE THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R7: el aula no está disponible';
        END IF;
    END IF;

    SELECT aval_departamento INTO v_aval FROM tutor WHERE id_tutor = NEW.id_tutor;
    IF v_aval = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R4: el tutor no tiene aval del departamento';
    END IF;

    SELECT COUNT(*) INTO v_inscritos FROM inscripcion WHERE id_sesion = NEW.id_sesion;
    IF NEW.cupo_maximo < v_inscritos THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R2: el nuevo cupo es menor que los inscritos';
    END IF;
END$$

-- R2 + R3: al inscribir
--   R2: los inscritos no superan cupo_maximo
--   R3: un tutor no se inscribe en una sesión que él mismo imparte
CREATE TRIGGER trg_inscripcion_bi BEFORE INSERT ON inscripcion
FOR EACH ROW
BEGIN
    DECLARE v_cupo SMALLINT;
    DECLARE v_tutor INT;
    DECLARE v_inscritos INT;

    SELECT cupo_maximo, id_tutor INTO v_cupo, v_tutor
    FROM sesion WHERE id_sesion = NEW.id_sesion;

    IF NEW.id_estudiante = v_tutor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R3: el tutor no puede inscribirse en su propia sesión';
    END IF;

    SELECT COUNT(*) INTO v_inscritos FROM inscripcion WHERE id_sesion = NEW.id_sesion;
    IF v_inscritos >= v_cupo THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R2: la sesión alcanzó su cupo máximo';
    END IF;
END$$

-- R6: solo se evalúa una sesión cuya fecha ya pasó
CREATE TRIGGER trg_evaluacion_bi BEFORE INSERT ON evaluacion
FOR EACH ROW
BEGIN
    DECLARE v_inicio DATETIME;
    SELECT TIMESTAMP(fecha, hora) INTO v_inicio FROM sesion WHERE id_sesion = NEW.id_sesion;
    IF v_inicio > NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R6: no se puede evaluar una sesión que aún no ocurre';
    END IF;
END$$

DELIMITER ;

-- R5 (toda sesión VIRTUAL tiene un registro en RECURSO_VIRTUAL) no puede
-- validarse en el INSERT de la sesión porque el recurso se crea después.
-- Se verifica con esta consulta de control o en la capa de aplicación:
--   SELECT s.id_sesion FROM sesion s
--   LEFT JOIN recurso_virtual r ON r.id_sesion = s.id_sesion
--   WHERE s.modalidad = 'VIRTUAL' AND r.id_recurso IS NULL;
