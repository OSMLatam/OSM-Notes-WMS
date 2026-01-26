# ADR-0002: Use GeoServer for WMS

## Status

Accepted

## Context

We need to provide WMS (Web Map Service) layers for OSM notes so mappers can visualize notes in mapping applications like JOSM and Vespucci. We need a standards-compliant WMS server that can serve spatial data from PostgreSQL/PostGIS.

## Decision

We will use GeoServer as the WMS server to publish OSM notes layers.

## Consequences

### Positive

- **Standards compliant**: OGC WMS 1.3.0 compliant
- **Mature and stable**: Well-established, production-ready software
- **PostGIS integration**: Excellent integration with PostGIS
- **REST API**: REST API for configuration and management
- **Styling**: Support for SLD (Styled Layer Descriptor) for custom styling
- **Multiple formats**: Supports multiple output formats (PNG, JPEG, GeoJSON, etc.)
- **Open source**: No licensing costs
- **Active community**: Large community and good documentation

### Negative

- **Java dependency**: Requires Java Runtime Environment
- **Resource usage**: Can be memory-intensive
- **Configuration complexity**: Complex configuration for advanced features
- **Learning curve**: Team needs to learn GeoServer configuration

## Alternatives Considered

### Alternative 1: MapServer

- **Description**: Use MapServer as WMS server
- **Pros**: Lightweight, C-based, good performance
- **Cons**: Less user-friendly configuration, smaller community
- **Why not chosen**: GeoServer has better REST API and more modern tooling

### Alternative 2: Custom WMS implementation

- **Description**: Build custom WMS server
- **Pros**: Full control, no external dependencies
- **Cons**: Significant development effort, must implement OGC standards, maintenance burden
- **Why not chosen**: GeoServer provides all needed features without custom development

### Alternative 3: PostGIS raster functions

- **Description**: Use PostGIS raster functions directly
- **Pros**: No additional server, direct database access
- **Cons**: Not a full WMS server, limited functionality, complex to implement
- **Why not chosen**: GeoServer provides complete WMS functionality

## References

- [GeoServer Documentation](https://docs.geoserver.org/)
- [WMS Guide](WMS_Guide.md)
