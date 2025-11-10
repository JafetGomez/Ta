USE [Facturacion];
GO

SET NOCOUNT ON;

DECLARE @XmlData XML;
DECLARE @idoc INT;
DECLARE @passwordAdmin VARCHAR(64); 

SET @XmlData = '
<Catalogos>
    <!--   Parámetros para el sistema, como fecha en la que se hacen los cobros   -->
    <ParametrosSistema>
        <DiasVencimientoFactura>15</DiasVencimientoFactura>
        <DiasGraciaCorta>10</DiasGraciaCorta>
    </ParametrosSistema>
    <TipoMovimientoLecturaMedidor>
        <TipoMov id="1" nombre="Lectura"/>
        <TipoMov id="2" nombre="Ajuste Crédito"/>
        <TipoMov id="3" nombre="Ajuste Débito"/>
    </TipoMovimientoLecturaMedidor>
    <TipoUsoPropiedad>
        <TipoUso id="1" nombre="Habitación"/>
        <TipoUso id="2" nombre="Comercial"/>
        <TipoUso id="3" nombre="Industrial"/>
        <TipoUso id="4" nombre="Lote Baldío"/>
        <TipoUso id="5" nombre="Agrícola"/>
    </TipoUsoPropiedad>
    <TipoZonaPropiedad>
        <TipoZona id="1" nombre="Residencial"/>
        <TipoZona id="2" nombre="Agrícola"/>
        <TipoZona id="3" nombre="Bosque"/>
        <TipoZona id="4" nombre="Industrial"/>
        <TipoZona id="5" nombre="Comercial"/>
    </TipoZonaPropiedad>
    <UsuarioAdmin>
        <Admin id="1" nombre="Administrador" password="SoyAdmin"/>
    </UsuarioAdmin>
    <TipoAsociacion>
        <TipoAso id="1" nombre="Asociar"/>
        <TipoAso id="2" nombre="Desasociar"/>
    </TipoAsociacion>
    <TipoMedioPago>
        <MedioPago id="1" nombre="Efectivo"/>
        <MedioPago id="2" nombre="Tarjeta"/>
    </TipoMedioPago>
    <PeriodoMontoCC>
        <PeriodoMonto id="1" nombre="Mensual" qMeses="1"/>
        <PeriodoMonto id="2" nombre="Trimestral" qMeses="3"/>
        <PeriodoMonto id="3" nombre="Semestral" qMeses="6"/>
        <PeriodoMonto id="4" nombre="Anual" qMeses="12"/>
        <PeriodoMonto id="5" nombre="Único" qMeses="1"/>
        <PeriodoMonto id="6" nombre="Interés Diario" qMeses="1" dias="30"/>
        <!--   Consderar año bisiesto en SPs  -->
    </PeriodoMontoCC>
    <TipoMontoCC>
        <TipoMonto id="1" nombre="Monto Fijo"/>
        <TipoMonto id="2" nombre="Monto Variable"/>
        <TipoMonto id="3" nombre="Porcentaje"/>
    </TipoMontoCC>
    <CCs>
        <CC id="1" nombre="ConsumoAgua" TipoMontoCC="2" PeriodoMontoCC="1" ValorMinimo="5000" ValorMinimoM3="30" ValorFijoM3Adicional="1000" ValorPorcentual="" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
        <CC id="2" nombre="PatenteComercial" TipoMontoCC="1" PeriodoMontoCC="3" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="150000" ValorM2Minimo="" ValorTramosM2=""/>
        <CC id="3" nombre="ImpuestoPropiedad" TipoMontoCC="3" PeriodoMontoCC="4" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="0.01" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
        <CC id="4" nombre="RecoleccionBasura" TipoMontoCC="1" PeriodoMontoCC="1" ValorMinimo="150" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="300" ValorM2Minimo="400" ValorTramosM2="75"/>
        <CC id="5" nombre="MantenimientoParques" TipoMontoCC="1" PeriodoMontoCC="1" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="2000" ValorM2Minimo="" ValorTramosM2=""/>
        <CC id="6" nombre="ReconexionAgua" TipoMontoCC="1" PeriodoMontoCC="5" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="" ValorFijo="30000" ValorM2Minimo="" ValorTramosM2=""/>
        <CC id="7" nombre="InteresesMoratorios" TipoMontoCC="3" PeriodoMontoCC="6" ValorMinimo="" ValorMinimoM3="" ValorFijoM3Adicional="" ValorPorcentual="0.04" ValorFijo="" ValorM2Minimo="" ValorTramosM2=""/>
    </CCs>
</Catalogos>
';

EXEC sys.sp_xml_preparedocument @idoc OUTPUT
                              , @XmlData;

BEGIN TRY

    BEGIN TRANSACTION
    
        INSERT INTO [dbo].[ParametrosSistema] (
            DiasVencimientoFactura
          , DiasGraciaCorta
        )
        SELECT
            DiasVencimientoFactura
          , DiasGraciaCorta
        FROM OPENXML (@idoc, '/Catalogos/ParametrosSistema', 2)
        WITH (
            DiasVencimientoFactura INT 'DiasVencimientoFactura'
          , DiasGraciaCorta        INT 'DiasGraciaCorta'
        );

        INSERT INTO [dbo].[TipoMovimientoLecturaMedidor] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoMovimientoLecturaMedidor/TipoMov', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[TipoUsoPropiedad] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoUsoPropiedad/TipoUso', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[TipoZonaPropiedad] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoZonaPropiedad/TipoZona', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        SELECT @passwordAdmin = password
        FROM OPENXML (@idoc, '/Catalogos/UsuarioAdmin/Admin', 2)
        WITH (
            password VARCHAR(100) '@password'
        );

        INSERT INTO [dbo].[UsuarioAdmin] (
            [id]
          , [nombre]
          , [password]
        )
        SELECT
            id
          , nombre
          , @passwordAdmin 
        FROM OPENXML (@idoc, '/Catalogos/UsuarioAdmin/Admin', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[TipoAsociacion] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoAsociacion/TipoAso', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[TipoMedioPago] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoMedioPago/MedioPago', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[PeriodoMontoCC] (
            [id]
          , [nombre]
          , [qMeses]
          , [dias]
        )
        SELECT
            id
          , nombre
          , qMeses
          , dias
        FROM OPENXML (@idoc, '/Catalogos/PeriodoMontoCC/PeriodoMonto', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
          , qMeses INT         '@qMeses'
          , dias   INT         '@dias'
        );

        INSERT INTO [dbo].[TipoMontoCC] (
            [id]
          , [nombre]
        )
        SELECT
            id
          , nombre
        FROM OPENXML (@idoc, '/Catalogos/TipoMontoCC/TipoMonto', 2)
        WITH (
            id     INT         '@id'
          , nombre VARCHAR(64) '@nombre'
        );

        INSERT INTO [dbo].[ConceptoCobro] (
            [id]
          , [nombre]
          , [idTipoMontoCC]
          , [idPeriodoMontoCC]
          , [ValorMinimo]
          , [ValorMinimoM3]
          , [ValorFijoM3Adicional]
          , [ValorPorcentual]
          , [ValorFijo]
          , [ValorM2Minimo]
          , [ValorTramosM2]
        )
        SELECT
            id
          , nombre
          , TipoMontoCC
          , PeriodoMontoCC
          , ValorMinimo
          , ValorMinimoM3
          , ValorFijoM3Adicional
          , ValorPorcentual
          , ValorFijo
          , ValorM2Minimo
          , ValorTramosM2
        FROM OPENXML (@idoc, '/Catalogos/CCs/CC', 2)
        WITH (
            id                       INT    '@id'
          , nombre                   VARCHAR(64) '@nombre'
          , TipoMontoCC              INT    '@TipoMontoCC'
          , PeriodoMontoCC           INT    '@PeriodoMontoCC'
          , ValorMinimo              FLOAT  '@ValorMinimo'
          , ValorMinimoM3            FLOAT  '@ValorMinimoM3'
          , ValorFijoM3Adicional     FLOAT  '@ValorFijoM3Adicional'
          , ValorPorcentual          FLOAT  '@ValorPorcentual'
          , ValorFijo                FLOAT  '@ValorFijo'
          , ValorM2Minimo            FLOAT  '@ValorM2Minimo'
          , ValorTramosM2            FLOAT  '@ValorTramosM2'
        );

    COMMIT TRANSACTION
    
    PRINT 'Datos de catálogos insertados correctamente usando OPENXML!';

END TRY
BEGIN CATCH

    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;

    DECLARE @ErrorMessage NVARCHAR(MAX)
          , @ErrorSeverity INT
          , @ErrorState INT;
    
    SELECT @ErrorMessage = ERROR_MESSAGE()
         , @ErrorSeverity = ERROR_SEVERITY()
         , @ErrorState = ERROR_STATE();
    
    
    INSERT INTO [dbo].[DBErrors] (
          ErrorDateTime
        , ErrorMessage
        , ErrorSeverity
        , ErrorState
        , ProcedureName
    )
    VALUES (
          GETDATE()
        , @ErrorMessage
        , @ErrorSeverity
        , @ErrorState
        , OBJECT_NAME(@@PROCID) 
    );
   
    IF (@idoc IS NOT NULL)
        EXEC sys.sp_xml_removedocument @idoc;
        
    
    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH


IF (@idoc IS NOT NULL)
    EXEC sys.sp_xml_removedocument @idoc;
GO

-- Usar la base de datos Facturacion
USE [Facturacion];
GO

PRINT '--- 1. ParametrosSistema ---';
SELECT * FROM [dbo].[ParametrosSistema];
GO

PRINT '--- 2. TipoMovimientoLecturaMedidor ---';
SELECT * FROM [dbo].[TipoMovimientoLecturaMedidor];
GO

PRINT '--- 3. TipoUsoPropiedad ---';
SELECT * FROM [dbo].[TipoUsoPropiedad];
GO


PRINT '--- 4. TipoZonaPropiedad ---';
SELECT * FROM [dbo].[TipoZonaPropiedad];
GO

PRINT '--- 5. TipoAsociacion ---';
SELECT * FROM [dbo].[TipoAsociacion];
GO

PRINT '--- 6. TipoMedioPago ---';
SELECT * FROM [dbo].[TipoMedioPago];
GO

PRINT '--- 7. PeriodoMontoCC ---';
SELECT * FROM [dbo].[PeriodoMontoCC];
GO

PRINT '--- 8. TipoMontoCC ---';
SELECT * FROM [dbo].[TipoMontoCC];
GO

PRINT '--- 9. ConceptoCobro ---';
SELECT * FROM [dbo].[ConceptoCobro];
GO

PRINT '--- 10. UsuarioAdmin ---';
SELECT * FROM [dbo].[UsuarioAdmin];
GO