# Convenciones de la base de datos AutoManagerDMS

Acuerdos para que todos los módulos usen una sola base de datos de forma consistente.
Cada integrante mantiene sus propios scripts; este documento solo describe las reglas comunes.

## 1. Fechas: siempre en UTC

- Las columnas de fecha usan `DATETIME2` y su valor por defecto es **`SYSUTCDATETIME()`**.
- **No usar `SYSDATETIME()` ni `GETDATE()`**: devuelven la hora local *del servidor*.
  En Docker el servidor está en UTC, pero en SQL Server Express de Windows está en hora de
  Guatemala, así que la misma columna guardaría horas distintas según la computadora.
- La aplicación convierte a hora de Guatemala **solo al mostrar**, con
  `CapaLogica.ClsZonaHorariaLN.fncConvertirUtcAGuatemala`. Para mostrar una fecha en una
  página se puede usar `ClsFormatoSC.fncFormatearFechaSC`, que ya hace esa conversión.
- Al leer una fecha con `SqlDataReader`, marcarla como UTC para evitar conversiones dobles:

  ```csharp
  DateTime.SpecifyKind(lector.GetDateTime(i), DateTimeKind.Utc)
  ```

- Para filtrar por fechas locales (por ejemplo, "órdenes de hoy"), convertir primero el
  inicio y el fin del día de Guatemala a UTC con `ClsZonaHorariaLN.fncConvertirGuatemalaAUtc`.

## 2. Relación con vehículos

Las tablas que se refieren a un vehículo usan su **VIN**. En `dbo.Vehiculos` el VIN es
obligatorio y único (restricción `UQ_Vehiculos_VIN`), igual que la placa:

```sql
VIN VARCHAR(17) NOT NULL,
CONSTRAINT FK_<Tabla>_Vehiculos
    FOREIGN KEY (VIN) REFERENCES dbo.Vehiculos (VIN) ON UPDATE CASCADE
```

`ON UPDATE CASCADE` hace que, si se corrige un VIN mal escrito en `dbo.Vehiculos`, las filas
relacionadas se actualicen solas. La placa y el propietario se obtienen con un `JOIN`
(`ON v.VIN = o.VIN`) a `dbo.Vehiculos` y `dbo.Clientes`.
Desde C# se pueden usar `ClsVehiculoLNSC.fncBuscarVehiculosSC(placaOVin)` (el VIN exacto
aparece primero) y `ClsVehiculoLNSC.fncObtenerVehiculoSC(idVehiculo)`.

## 3. Ejemplo para `OrdenesReparacion` (propuesta para Neider)

Este es el script `OrdenesReparacionNT.sql` con los ajustes de las secciones 1, 2 y 4.
Es solo una referencia: el archivo original no se ha modificado.

```sql
IF OBJECT_ID(N'dbo.OrdenesReparacion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrdenesReparacion (
        IdOrden INT IDENTITY(1,1) NOT NULL,
        VIN VARCHAR(17) NOT NULL,
        FechaApertura DATETIME2 NOT NULL
            CONSTRAINT DF_OrdenesReparacion_FechaApertura DEFAULT SYSUTCDATETIME(),
        MotivoIngreso NVARCHAR(500) NOT NULL,
        Diagnostico NVARCHAR(1000) NULL,
        Estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_OrdenesReparacion_Estado DEFAULT 'Abierta',
        FechaCierre DATETIME2 NULL,
        ObservacionesCierre NVARCHAR(1000) NULL,

        CONSTRAINT PK_OrdenesReparacion PRIMARY KEY (IdOrden),
        CONSTRAINT FK_OrdenesReparacion_Vehiculos
            FOREIGN KEY (VIN) REFERENCES dbo.Vehiculos (VIN) ON UPDATE CASCADE,
        CONSTRAINT CK_OrdenesReparacion_Estado
            CHECK (Estado IN ('Abierta', 'Cerrada')),
        -- Una orden abierta no tiene fecha de cierre y una cerrada sí.
        CONSTRAINT CK_OrdenesReparacion_Cierre
            CHECK ((Estado = 'Abierta' AND FechaCierre IS NULL)
                OR (Estado = 'Cerrada' AND FechaCierre IS NOT NULL AND FechaCierre >= FechaApertura)),
        CONSTRAINT CK_OrdenesReparacion_Motivo
            CHECK (LEN(MotivoIngreso) > 0)
    );
END
GO

-- Acelera el historial de reparaciones por VIN.
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_OrdenesReparacion_VIN' AND object_id = OBJECT_ID(N'dbo.OrdenesReparacion'))
BEGIN
    CREATE INDEX IX_OrdenesReparacion_VIN ON dbo.OrdenesReparacion (VIN);
END
GO
```

El formato del VIN no hace falta validarlo otra vez: la llave foránea solo acepta VIN que ya
existen en `dbo.Vehiculos`, donde `CK_Vehiculos_VIN` revisa los 17 caracteres sin I, O ni Q.

Si `FechaCierre` se llena desde SQL, usar también `SYSUTCDATETIME()`; si se llena desde C#,
usar `DateTime.UtcNow`.

## 4. Scripts

- Un script por módulo en `database/`, con número para fijar el orden de ejecución:
  `00_` crea la base, `01_ClientesVehiculosSC.sql`, `02_OrdenesReparacionNT.sql`, etc.
  Docker ejecuta automáticamente los archivos `database/[0-9][0-9]_*.sql` en orden.
- Cada script empieza con `USE AutoManagerDMS;` y debe poder ejecutarse varias veces
  (`IF OBJECT_ID(...) IS NULL`, `IF DB_ID(...) IS NULL`, `IF NOT EXISTS (...)`).
- Todas las restricciones llevan nombre (`PK_`, `FK_`, `UQ_`, `CK_`, `DF_`, `IX_`, `UX_`)
  para que sean iguales en todas las computadoras y se puedan modificar después.
- Incluir `SET QUOTED_IDENTIFIER ON;` al inicio (es la configuración que recomienda SQL Server
  y la obligatoria si algún módulo crea índices filtrados); con `sqlcmd`, usar la opción `-I`.

## 5. Identificadores

- `IDENTITY_CACHE` está desactivado en `AutoManagerDMS` para evitar saltos de 1000 cuando
  el servidor se detiene. Aun así, **los identificadores pueden tener huecos** (por ejemplo,
  si una transacción se deshace); no se debe suponer que son consecutivos.

## 6. Conexión desde C#

- Obtener las conexiones siempre con `CapaDatos.ClsConexionDA.fncObtenerConexion()`.
- La cadena de conexión `AutoManagerDMS` está en `CapaPresentacion/ConnectionStrings.config`
  (local, no se sube a GitHub; plantilla: `ConnectionStrings.config.example`).
- Usar siempre parámetros (`SqlCommand.Parameters`), nunca concatenar datos del usuario.
