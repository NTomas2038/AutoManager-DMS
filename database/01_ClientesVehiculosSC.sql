
-- AutoManager DMS
-- Modulo 1: Clientes y vehiculos
-- Integrante: Sharon Consuegra
-- Crea las tablas Clientes y Vehiculos con sus restricciones e indices.
-- Se puede ejecutar varias veces: solo crea lo que todavia no existe.
-- Requiere que la base AutoManagerDMS ya exista.
-- Fechas: FechaRegistro se guarda en UTC (SYSUTCDATETIME) en cualquier servidor.
-- La aplicacion la convierte a la hora de Guatemala solo al mostrarla.

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON; -- Obligatorio para crear el indice filtrado del VIN.
GO

USE AutoManagerDMS;
GO

IF OBJECT_ID(N'dbo.Clientes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clientes (
        IdCliente INT IDENTITY(1,1) NOT NULL,
        DPI CHAR(13) NOT NULL,
        Nombres NVARCHAR(80) NOT NULL,
        Apellidos NVARCHAR(80) NOT NULL,
        Telefono VARCHAR(15) NOT NULL,
        Correo NVARCHAR(254) NULL,
        Direccion NVARCHAR(200) NULL,
        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_Clientes_FechaRegistro DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_Clientes
            PRIMARY KEY (IdCliente),

        -- Criterio de duplicado: un DPI por cliente.
        CONSTRAINT UQ_Clientes_DPI
            UNIQUE (DPI),

        CONSTRAINT CK_Clientes_DPI
            CHECK (LEN(DPI) = 13 AND DPI NOT LIKE '%[^0-9]%'),

        CONSTRAINT CK_Clientes_Nombres
            CHECK (LEN(Nombres) > 0),

        CONSTRAINT CK_Clientes_Apellidos
            CHECK (LEN(Apellidos) > 0),

        CONSTRAINT CK_Clientes_Telefono
            CHECK (LEN(Telefono) BETWEEN 8 AND 15 AND Telefono NOT LIKE '%[^0-9]%'),

        CONSTRAINT CK_Clientes_Correo
            CHECK (Correo IS NULL OR Correo LIKE '_%@_%._%')
    );
END
GO

IF OBJECT_ID(N'dbo.Vehiculos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Vehiculos (
        IdVehiculo INT IDENTITY(1,1) NOT NULL,
        IdCliente INT NOT NULL,
        Placa VARCHAR(10) NOT NULL,
        VIN VARCHAR(17) NULL,
        Marca NVARCHAR(50) NOT NULL,
        Modelo NVARCHAR(50) NOT NULL,
        Anio SMALLINT NOT NULL,
        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_Vehiculos_FechaRegistro DEFAULT SYSUTCDATETIME(),

        -- Identificador que usaran las ordenes de reparacion (FK por IdVehiculo).
        CONSTRAINT PK_Vehiculos
            PRIMARY KEY (IdVehiculo),

        CONSTRAINT FK_Vehiculos_Clientes
            FOREIGN KEY (IdCliente) REFERENCES dbo.Clientes (IdCliente),

        CONSTRAINT UQ_Vehiculos_Placa
            UNIQUE (Placa),

        -- La placa se guarda normalizada: mayusculas y numeros, sin espacios ni guiones.
        CONSTRAINT CK_Vehiculos_Placa
            CHECK (LEN(Placa) BETWEEN 5 AND 10
                AND Placa COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9]%'),

        -- VIN estandar: 17 caracteres sin las letras I, O ni Q.
        CONSTRAINT CK_Vehiculos_VIN
            CHECK (VIN IS NULL OR (LEN(VIN) = 17
                AND VIN COLLATE Latin1_General_BIN NOT LIKE '%[^A-HJ-NPR-Z0-9]%')),

        CONSTRAINT CK_Vehiculos_Marca
            CHECK (LEN(Marca) > 0),

        CONSTRAINT CK_Vehiculos_Modelo
            CHECK (LEN(Modelo) > 0),

        -- Solo el limite fijo. El maximo (anio actual + 1) se valida en
        -- la Capa Logica, porque depende de la fecha.
        CONSTRAINT CK_Vehiculos_Anio
            CHECK (Anio >= 1900)
    );
END
GO

-- El VIN es opcional, pero si se registra no puede repetirse.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'UX_Vehiculos_VIN' AND object_id = OBJECT_ID(N'dbo.Vehiculos'))
BEGIN
    CREATE UNIQUE INDEX UX_Vehiculos_VIN
        ON dbo.Vehiculos (VIN)
        WHERE VIN IS NOT NULL;
END
GO

-- Acelera la consulta de los vehiculos de un cliente.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_Vehiculos_IdCliente' AND object_id = OBJECT_ID(N'dbo.Vehiculos'))
BEGIN
    CREATE INDEX IX_Vehiculos_IdCliente
        ON dbo.Vehiculos (IdCliente);
END
GO

-- Actualizacion para bases creadas antes de usar UTC: si el DEFAULT todavia es
-- SYSDATETIME() (hora local del servidor), se reemplaza por SYSUTCDATETIME().
-- No modifica los registros existentes; solo el valor de los nuevos.
IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = N'DF_Clientes_FechaRegistro' AND definition <> N'(sysutcdatetime())')
BEGIN
    ALTER TABLE dbo.Clientes DROP CONSTRAINT DF_Clientes_FechaRegistro;
    ALTER TABLE dbo.Clientes ADD CONSTRAINT DF_Clientes_FechaRegistro
        DEFAULT SYSUTCDATETIME() FOR FechaRegistro;
END
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints
           WHERE name = N'DF_Vehiculos_FechaRegistro' AND definition <> N'(sysutcdatetime())')
BEGIN
    ALTER TABLE dbo.Vehiculos DROP CONSTRAINT DF_Vehiculos_FechaRegistro;
    ALTER TABLE dbo.Vehiculos ADD CONSTRAINT DF_Vehiculos_FechaRegistro
        DEFAULT SYSUTCDATETIME() FOR FechaRegistro;
END
GO

PRINT N'Modulo 1: tablas Clientes y Vehiculos listas.';
GO
