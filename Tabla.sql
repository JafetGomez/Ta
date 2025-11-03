-- Verificar y crear la Base de Datos
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Facturacion')
BEGIN
    CREATE DATABASE [Facturacion];
END
GO

USE [Facturacion];
GO


-- 1. Tipos de Movimiento de Lectura
CREATE TABLE [dbo].[TipoMovimientoLecturaMedidor] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoMovimientoLecturaMedidor] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 2. Tipos de Uso de Propiedad
CREATE TABLE [dbo].[TipoUsoPropiedad] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoUsoPropiedad] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 3. Tipos de Zona de Propiedad
CREATE TABLE [dbo].[TipoZonaPropiedad] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoZonaPropiedad] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 4. Tipos de Asociaci�n
CREATE TABLE [dbo].[TipoAsociacion] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoAsociacion] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 5. Tipos de Medio de Pago
CREATE TABLE [dbo].[TipoMedioPago] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoMedioPago] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 6. Tipos de Monto/C�lculo
CREATE TABLE [dbo].[TipoMontoCC] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    CONSTRAINT [PK_TipoMontoCC] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 7. Periodicidad de Cobro
CREATE TABLE [dbo].[PeriodoMontoCC] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    [qMeses] [int] NOT NULL,
    [dias] [int] NULL,
    CONSTRAINT [PK_PeriodoMontoCC] PRIMARY KEY CLUSTERED ([id] ASC)
);

-- 8. Conceptos de Cobro 
CREATE TABLE [dbo].[ConceptoCobro] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    [idTipoMontoCC] [int] NOT NULL,
    [idPeriodoMontoCC] [int] NOT NULL,
    [ValorMinimo] [float] NULL,
    [ValorMinimoM3] [float] NULL,
    [ValorFijoM3Adicional] [float] NULL,
    [ValorPorcentual] [float] NULL,
    [ValorFijo] [float] NULL,
    [ValorM2Minimo] [float] NULL,
    [ValorTramosM2] [float] NULL,
    CONSTRAINT [PK_ConceptoCobro] PRIMARY KEY CLUSTERED ([id] ASC),
    FOREIGN KEY ([idPeriodoMontoCC]) REFERENCES [dbo].[PeriodoMontoCC] ([id]),
    FOREIGN KEY ([idTipoMontoCC]) REFERENCES [dbo].[TipoMontoCC] ([id])
);

-- 9. Par�metros de configuraci�n del sistema 
CREATE TABLE [dbo].[ParametrosSistema] (
    [DiasVencimientoFactura] [int] NOT NULL,
    [DiasGraciaCorta] [int] NOT NULL
);

-- 10. Cat�logo de Usuarios Administradores 
CREATE TABLE [dbo].[UsuarioAdmin] (
    [id] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    [password] [varchar](100) NOT NULL,
    CONSTRAINT [PK_UsuarioAdmin] PRIMARY KEY CLUSTERED ([id] ASC),
    CONSTRAINT [UQ_AdminNombre] UNIQUE ([nombre])
);
