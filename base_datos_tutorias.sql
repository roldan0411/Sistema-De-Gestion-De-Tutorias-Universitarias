-- =====================================================
-- Base de datos: Sistema de tutorías
-- Compatible con MySQL 8+ / MariaDB (y con mínimos cambios PostgreSQL)
-- =====================================================

DROP DATABASE IF EXISTS tutorias;
CREATE DATABASE tutorias CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tutorias;

-- ---------- Departamento ----------
CREATE TABLE departamento (
    id_departamento INT PRIMARY KEY AUTO_INCREMENT,
    nombre          VARCHAR(100) NOT NULL
);

-- ---------- Estudiante ----------
CREATE TABLE estudiante (
    id_estudiante INT PRIMARY KEY AUTO_INCREMENT,
    nombre        VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    semestre      INT NOT NULL CHECK (semestre > 0),
    promedio      DECIMAL(3,2) CHECK (promedio BETWEEN 0 AND 5)
);

-- ---------- Tutor (un tutor ES un estudiante: relación 1:1 "Es") ----------
CREATE TABLE tutor (
    id_tutor            INT PRIMARY KEY,
    id_departamento     INT NOT NULL,
    semestre_habilitado INT NOT NULL CHECK (semestre_habilitado > 0),
    aval_departamento   BOOLEAN NOT NULL DEFAULT FALSE,
    nota_minima_aprobada DECIMAL(3,2) NOT NULL CHECK (nota_minima_aprobada BETWEEN 0 AND 5),
    CONSTRAINT fk_tutor_estudiante   FOREIGN KEY (id_tutor)        REFERENCES estudiante(id_estudiante),
    CONSTRAINT fk_tutor_departamento FOREIGN KEY (id_departamento) REFERENCES departamento(id_departamento)
);

-- ---------- Materia (Pertenece Materia: Departamento 1 - N Materia) ----------
CREATE TABLE materia (
    id_materia      INT PRIMARY KEY AUTO_INCREMENT,
    nombre          VARCHAR(100) NOT NULL,
    id_departamento INT NOT NULL,
    CONSTRAINT fk_materia_departamento FOREIGN KEY (id_departamento) REFERENCES departamento(id_departamento)
);

-- ---------- Aula (Pertenece Aula: Departamento 1 - N Aula) ----------
CREATE TABLE aula (
    id_aula         INT PRIMARY KEY AUTO_INCREMENT,
    capacidad       INT NOT NULL CHECK (capacidad > 0),
    disponibilidad  BOOLEAN NOT NULL DEFAULT TRUE,
    id_departamento INT NOT NULL,
    CONSTRAINT fk_aula_departamento FOREIGN KEY (id_departamento) REFERENCES departamento(id_departamento)
);

-- ---------- Recurso virtual ----------
CREATE TABLE recurso_virtual (
    id_recurso INT PRIMARY KEY AUTO_INCREMENT,
    plataforma VARCHAR(50)  NOT NULL,
    enlace     VARCHAR(255) NOT NULL
);

-- ---------- Sesión ----------
-- Imparte (Tutor 1 - N Sesión), Es de (Materia 1 - N Sesión),
-- Se realiza en (Aula 1 - 1 Sesión), Usa (Sesión 1 - 1 RecursoVirtual)
-- id_aula e id_recurso son NULL según la modalidad (presencial / virtual)
CREATE TABLE sesion (
    id_sesion  INT PRIMARY KEY AUTO_INCREMENT,
    fecha      DATE NOT NULL,
    hora       TIME NOT NULL,
    modalidad  ENUM('presencial','virtual') NOT NULL,
    cupo_maximo INT NOT NULL CHECK (cupo_maximo > 0),
    id_tutor   INT NOT NULL,
    id_materia INT NOT NULL,
    id_aula    INT NULL,
    id_recurso INT NULL UNIQUE,
    CONSTRAINT fk_sesion_tutor   FOREIGN KEY (id_tutor)   REFERENCES tutor(id_tutor),
    CONSTRAINT fk_sesion_materia FOREIGN KEY (id_materia) REFERENCES materia(id_materia),
    CONSTRAINT fk_sesion_aula    FOREIGN KEY (id_aula)    REFERENCES aula(id_aula),
    CONSTRAINT fk_sesion_recurso FOREIGN KEY (id_recurso) REFERENCES recurso_virtual(id_recurso),
    CONSTRAINT chk_modalidad CHECK (
        (modalidad = 'presencial' AND id_aula IS NOT NULL AND id_recurso IS NULL) OR
        (modalidad = 'virtual'    AND id_recurso IS NOT NULL AND id_aula IS NULL)
    )
);

-- ---------- Inscribe (Estudiante N - M Sesión) ----------
CREATE TABLE inscripcion (
    id_estudiante     INT NOT NULL,
    id_sesion         INT NOT NULL,
    fecha_inscripcion DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (id_estudiante, id_sesion),
    CONSTRAINT fk_insc_estudiante FOREIGN KEY (id_estudiante) REFERENCES estudiante(id_estudiante),
    CONSTRAINT fk_insc_sesion     FOREIGN KEY (id_sesion)     REFERENCES sesion(id_sesion)
);

-- ---------- Evalúa (Estudiante N - M Sesión) ----------
CREATE TABLE evaluacion (
    id_estudiante INT NOT NULL,
    id_sesion     INT NOT NULL,
    calificacion  DECIMAL(2,1) NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario    TEXT,
    PRIMARY KEY (id_estudiante, id_sesion),
    CONSTRAINT fk_eval_estudiante FOREIGN KEY (id_estudiante) REFERENCES estudiante(id_estudiante),
    CONSTRAINT fk_eval_sesion     FOREIGN KEY (id_sesion)     REFERENCES sesion(id_sesion)
);

-- ---------- Índices útiles ----------
CREATE INDEX idx_sesion_fecha   ON sesion(fecha);
CREATE INDEX idx_sesion_tutor   ON sesion(id_tutor);
CREATE INDEX idx_sesion_materia ON sesion(id_materia);
