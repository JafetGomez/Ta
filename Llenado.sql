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



-- 11. Persona/Cliente
CREATE TABLE [dbo].[Persona] (
    [ValorDocumento] [int] NOT NULL,
    [nombre] [varchar](64) NOT NULL,
    [email] [varchar](64) NOT NULL,
    [telefono] [varchar](64) NOT NULL,
    CONSTRAINT [PK_Persona] PRIMARY KEY CLUSTERED ([ValorDocumento] ASC),
);

-- 12. Propiedad/Finca
CREATE TABLE [dbo].[Propiedad] (
    [NumeroFinca] [varchar](64) NOT NULL,
    [NumeroMedidor] [varchar](64) NOT NULL,
    [MetrosCuadrados] [float] NOT NULL,
    [ValorFiscal] [float] NOT NULL,
    [idTipoUsoPropiedad] [int] NOT NULL,
    [idTipoZonaPropiedad] [int] NOT NULL,
    [FechaRegistro][date] NOT NULL,
    [SaldoM3][float] NOT NULL,
    [SaldoM3UltimaFactura] [float] NOT NULL,
    CONSTRAINT [PK_Propiedad] PRIMARY KEY CLUSTERED ([NumeroFinca] ASC),
    FOREIGN KEY ([idTipoUsoPropiedad]) REFERENCES [dbo].[TipoUsoPropiedad] ([id]),
    FOREIGN KEY ([idTipoZonaPropiedad]) REFERENCES [dbo].[TipoZonaPropiedad] ([id])
);

-- 13. Medidor
CREATE TABLE [dbo].[Medidor] (
    [NumeroMedidor] [varchar](64) NOT NULL,
    [NumeroFinca] [varchar](64) UNIQUE NOT NULL, 
    CONSTRAINT [PK_Medidor] PRIMARY KEY CLUSTERED ([NumeroMedidor] ASC),
    FOREIGN KEY ([NumeroFinca]) REFERENCES [dbo].[Propiedad] ([NumeroFinca])
);

-- 14. Relaci�n Persona-Propiedad 
CREATE TABLE [dbo].[PropiedadPersona] (
    [ValorDocumento] [int] NOT NULL,
    [NumeroFinca] [varchar](64) NOT NULL,
    [idTipoAsociacion] [int] NOT NULL,
    [FechaInicio][date] NOT NULL,
    [FechaFin][date] NULL,
    FOREIGN KEY ([ValorDocumento]) REFERENCES [dbo].[Persona] ([ValorDocumento]),
    FOREIGN KEY ([NumeroFinca]) REFERENCES [dbo].[Propiedad] ([NumeroFinca]),
    FOREIGN KEY ([idTipoAsociacion]) REFERENCES [dbo].[TipoAsociacion] ([id])
);

-- 15. Relaci�n ConceptoCobro-Propiedad 
CREATE TABLE [dbo].[CCPropiedad] (
    [NumeroFinca] [varchar](64) NOT NULL,
    [idConceptoCobro] [int] NOT NULL,
    [idTipoAsociacion] [int] NOT NULL,
    FOREIGN KEY ([NumeroFinca]) REFERENCES [dbo].[Propiedad] ([NumeroFinca]),
    FOREIGN KEY ([idConceptoCobro]) REFERENCES [dbo].[ConceptoCobro] ([id]),
    FOREIGN KEY ([idTipoAsociacion]) REFERENCES [dbo].[TipoAsociacion] ([id])
);


-- 16. Lecturas de Medidor 
CREATE TABLE [dbo].[LecturasMedidor] (
    [NumeroMedidor] [varchar](64) NOT NULL,
    [Valor] [float] NOT NULL,
    [idTipoMovimiento] [int] NOT NULL,
    SaldoAnterior FLOAT NULL,
    SaldoNuevo FLOAT NULL,
    FOREIGN KEY ([NumeroMedidor]) REFERENCES [dbo].[Medidor] ([NumeroMedidor]),
    FOREIGN KEY ([idTipoMovimiento]) REFERENCES [dbo].[TipoMovimientoLecturaMedidor] ([id])
);

-- 17. Pagos (Simulaci�n: Pagos)
CREATE TABLE [dbo].[Pagos] (
    [NumeroFinca] [varchar](64) NOT NULL,
    [idTipoMedioPago] [int] NOT NULL,
    [NumeroReferencia] [varchar](64) NOT NULL,
    FOREIGN KEY ([NumeroFinca]) REFERENCES [dbo].[Propiedad] ([NumeroFinca]),
    FOREIGN KEY ([idTipoMedioPago]) REFERENCES [dbo].[TipoMedioPago] ([id])
);

-- 18. Factura (Resultado del proceso de cobro)
CREATE TABLE [dbo].[Factura] (
    [NumeroComprobante] INT IDENTITY(1000,1) NOT NULL,
    [FechaGeneracion] [date] NOT NULL,
    [NumeroFinca] [varchar](64) NOT NULL,
    [FechaOperacion] [date] NOT NULL,
    [FechaVencimiento] [date] NOT NULL,
    [TotalAPagarOriginal] [money] NOT NULL,
    [TotalAPagarFinal] [money] NOT NULL,
    [Detalle] [text] NOT NULL,
    [Estado] [varchar](64) NOT NULL,
    CONSTRAINT [PK_Factura] PRIMARY KEY CLUSTERED ([NumeroComprobante] ASC),
    FOREIGN KEY ([NumeroFinca]) REFERENCES [dbo].[Propiedad] ([NumeroFinca])
);

-- 19. Detalle Factura
CREATE TABLE DetalleFactura (
    id INT IDENTITY PRIMARY KEY,
    NumeroComprobante INT NOT NULL,
    idConceptoCobro INT NOT NULL,
    Monto FLOAT NOT NULL,
    Descripcion VARCHAR(256),
    FOREIGN KEY (NumeroComprobante) REFERENCES Factura(NumeroComprobante),
    FOREIGN KEY (idConceptoCobro) REFERENCES ConceptoCobro(id)
);

-- 20. Orden Corte De Agua
CREATE TABLE OrdenCorteAgua (
    id INT IDENTITY PRIMARY KEY,
    NumeroFinca VARCHAR(64) NOT NULL,
    NumeroComprobante INT NOT NULL, -- Factura que gener� la corta
    FechaCorte DATE NOT NULL,
    Estado INT NOT NULL, -- 1: Pendiente, 2: Pagado
    FOREIGN KEY (NumeroFinca) REFERENCES Propiedad(NumeroFinca),
    FOREIGN KEY (NumeroComprobante) REFERENCES Factura(NumeroComprobante)
);

-- 21. Orden Reconexion De Agua

CREATE TABLE OrdenReconexionAgua (
    id INT IDENTITY PRIMARY KEY,
    idOrdenCorte INT NOT NULL,
    FechaReconexion DATE NOT NULL,
    FOREIGN KEY (idOrdenCorte) REFERENCES OrdenCorteAgua(id)
);


-- 22. Comprobante de pago
CREATE TABLE ComprobantePago (
    id INT IDENTITY PRIMARY KEY,
    NumeroComprobanteFactura INT NOT NULL,
    idTipoMedioPago INT NOT NULL,
    FechaPago DATE NOT NULL,
    Monto FLOAT NOT NULL,
    FOREIGN KEY (NumeroComprobanteFactura) REFERENCES Factura(NumeroComprobante),
    FOREIGN KEY (idTipoMedioPago) REFERENCES TipoMedioPago(id)
);
