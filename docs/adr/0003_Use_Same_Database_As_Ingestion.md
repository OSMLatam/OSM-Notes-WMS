# ADR-0003: Use Same Database as Ingestion

## Status

Accepted

## Context

WMS needs access to OSM notes data stored in PostgreSQL. We need to decide whether to use the same database as Ingestion or create a separate database.

## Decision

We will use the same PostgreSQL database as OSM-Notes-Ingestion, creating a separate `wms` schema for WMS-specific objects.

## Consequences

### Positive

- **No data duplication**: Single source of truth for notes data
- **Real-time updates**: WMS automatically sees updates from Ingestion
- **Simplified architecture**: One database to manage
- **No synchronization**: No need to sync data between databases
- **Resource efficiency**: Shared database resources
- **Consistency**: Data is always consistent

### Negative

- **Tight coupling**: WMS is coupled to Ingestion database
- **Schema dependency**: WMS depends on Ingestion schema structure
- **Shared resources**: Database resources are shared
- **Deployment dependency**: WMS requires Ingestion database

## Alternatives Considered

### Alternative 1: Separate database with replication

- **Description**: Create separate database and replicate data from Ingestion
- **Pros**: Isolation, independent scaling, no coupling
- **Cons**: Data duplication, replication complexity, synchronization lag
- **Why not chosen**: Unnecessary complexity, real-time access is preferred

### Alternative 2: Foreign Data Wrapper (FDW)

- **Description**: Use PostgreSQL FDW to access Ingestion database from separate WMS database
- **Pros**: Some isolation, can have separate database
- **Cons**: FDW overhead, more complex setup, still depends on Ingestion
- **Why not chosen**: Same database with schema separation is simpler

### Alternative 3: API-based access

- **Description**: WMS queries data via API instead of direct database access
- **Pros**: Loose coupling, API abstraction
- **Cons**: Performance overhead, API dependency, more complex
- **Why not chosen**: Direct database access provides better performance for WMS

## References

- [Database Schema Documentation](sql/wms/README.md)
- [WMS Guide](WMS_Guide.md)
