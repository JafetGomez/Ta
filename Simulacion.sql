USE [Facturacion];
GO

CREATE TRIGGER AsignarCCDefault
ON dbo.Propiedad
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @idTipoAsociacion INT = 1;


    -- 1. Consumo de agua 
    INSERT INTO dbo.CCPropiedad (NumeroFinca, idConceptoCobro, idTipoAsociacion)
    SELECT i.NumeroFinca, 1, @idTipoAsociacion
    FROM inserted AS i
    WHERE i.idTipoUsoPropiedad IN (1, 2, 3)  
      AND NOT EXISTS (
        SELECT 1 FROM dbo.CCPropiedad AS CCP 
        WHERE CCP.NumeroFinca = i.NumeroFinca AND CCP.idConceptoCobro = 1
    );

    -- 2. Recolección de basura 
    INSERT INTO dbo.CCPropiedad (NumeroFinca, idConceptoCobro, idTipoAsociacion)
    SELECT i.NumeroFinca, 4, @idTipoAsociacion
    FROM inserted AS i
    WHERE i.idTipoZonaPropiedad IN (1, 3, 4, 5) 
      AND NOT EXISTS (
        SELECT 1 FROM dbo.CCPropiedad AS CCP 
        WHERE CCP.NumeroFinca = i.NumeroFinca AND CCP.idConceptoCobro = 4
    );

    -- 3. Mantenimiento de parques 
    INSERT INTO dbo.CCPropiedad (NumeroFinca, idConceptoCobro, idTipoAsociacion)
    SELECT i.NumeroFinca, 5, @idTipoAsociacion
    FROM inserted AS i
    WHERE i.idTipoZonaPropiedad IN (1, 5) 
      AND NOT EXISTS (
        SELECT 1 FROM dbo.CCPropiedad AS CCP 
        WHERE CCP.NumeroFinca = i.NumeroFinca AND CCP.idConceptoCobro = 5
    );

END;
GO

