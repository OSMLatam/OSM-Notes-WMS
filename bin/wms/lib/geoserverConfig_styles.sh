#!/bin/bash
# GeoServer Configuration Style Functions
# Functions for managing GeoServer styles (SLD)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-29
# Function to extract style name from SLD file
extract_style_name_from_sld() {
 local SLD_FILE="${1}"
 # Extract the first <se:Name> or <Name> tag content from the SLD
 local STYLE_NAME
 STYLE_NAME=$(grep -oP '<(se:)?Name[^>]*>.*?</(se:)?Name>' "${SLD_FILE}" 2> /dev/null | head -1 | sed 's/.*>\(.*\)<.*/\1/' | tr -d ' ')
 echo "${STYLE_NAME}"
}

# Function to upload style
upload_style() {
 local SLD_FILE="${1}"
 local STYLE_NAME="${2}"
 local FORCE_UPLOAD="${FORCE:-false}"

 # Validate SLD file using centralized validation
 if ! __validate_input_file "${SLD_FILE}" "SLD style file"; then
  print_status "${YELLOW}" "⚠️  SLD file validation failed: ${SLD_FILE}"
  if [[ "${FORCE_UPLOAD}" == "true" ]]; then
   return 0 # Continue with --force
  fi
  return 1
 fi

 # Extract actual style name from SLD (may differ from STYLE_NAME parameter)
 local ACTUAL_STYLE_NAME
 ACTUAL_STYLE_NAME=$(extract_style_name_from_sld "${SLD_FILE}")
 if [[ -z "${ACTUAL_STYLE_NAME}" ]]; then
  # Fallback to provided name if extraction fails
  ACTUAL_STYLE_NAME="${STYLE_NAME}"
 fi

 # Check if style already exists (try both the provided name and the actual name)
 # IMPORTANT: Check in workspace-specific styles first, then global styles
 local STYLE_CHECK_URL="${GEOSERVER_URL}/rest/styles/${ACTUAL_STYLE_NAME}"
 if [[ -n "${GEOSERVER_WORKSPACE:-}" ]]; then
  STYLE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/styles/${ACTUAL_STYLE_NAME}"
 fi
 local TEMP_CHECK_FILE="${TMP_DIR}/style_check_${STYLE_NAME}_$$.tmp"
 local CHECK_HTTP_CODE
 CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_CHECK_FILE}" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)

 # If not found with actual name, try with provided name
 if [[ "${CHECK_HTTP_CODE}" != "200" ]] && [[ "${ACTUAL_STYLE_NAME}" != "${STYLE_NAME}" ]]; then
  STYLE_CHECK_URL="${GEOSERVER_URL}/rest/styles/${STYLE_NAME}"
  if [[ -n "${GEOSERVER_WORKSPACE:-}" ]]; then
   STYLE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/styles/${STYLE_NAME}"
  fi
  CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_CHECK_FILE}" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)
  if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
   ACTUAL_STYLE_NAME="${STYLE_NAME}"
  fi
 fi

 local TEMP_RESPONSE_FILE="${TMP_DIR}/style_response_${STYLE_NAME}_$$.tmp"
 local HTTP_CODE
 local RESPONSE_BODY

 # If style exists, delete it first to avoid corruption issues, then create it
 # This is important because GeoServer may cache a corrupted version of the style
 if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
  # Style exists, delete it first to avoid corruption issues
  print_status "${BLUE}" "   Removing existing style '${ACTUAL_STYLE_NAME}' before recreating..."
  local DELETE_CODE
  DELETE_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -X DELETE "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)
  if [[ "${DELETE_CODE}" == "200" ]] || [[ "${DELETE_CODE}" == "204" ]]; then
   sleep 2 # Wait a moment for GeoServer to process the deletion and clear cache
  fi
 fi
 # Create the style (either new or after deletion)
 if true; then
  # Style doesn't exist, create it (use the name from SLD, not the parameter)
  # GeoServer will extract the name from the SLD file itself
  # Use --data-binary to ensure the entire file is read correctly
  # Use application/vnd.ogc.se+xml to preserve SLD 1.1.0 format and SvgParameter elements
  # IMPORTANT: Upload to workspace-specific styles endpoint to ensure styles are in the correct workspace
  local STYLE_UPLOAD_URL="${GEOSERVER_URL}/rest/styles?name=${ACTUAL_STYLE_NAME}"
  if [[ -n "${GEOSERVER_WORKSPACE:-}" ]]; then
   STYLE_UPLOAD_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/styles?name=${ACTUAL_STYLE_NAME}"
  fi
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X POST \
   -H "Content-Type: application/vnd.ogc.se+xml" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   --data-binary "@${SLD_FILE}" \
   "${STYLE_UPLOAD_URL}" 2> /dev/null | tail -1)
 fi

 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 local STYLE_UPLOADED=false
 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' updated"
  else
   print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' uploaded"
  fi
  STYLE_UPLOADED=true
 elif [[ "${HTTP_CODE}" == "409" ]] || [[ "${HTTP_CODE}" == "403" ]]; then
  # 403 or 409 means style already exists - try to update it
  if [[ "${CHECK_HTTP_CODE}" != "200" ]]; then
   # Style exists but we couldn't find it by name, try updating with actual name
   # Use --data-binary to ensure the entire file is read correctly
   # Use application/vnd.ogc.se+xml to preserve SLD 1.1.0 format and SvgParameter elements
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
    -X PUT \
    -H "Content-Type: application/vnd.ogc.se+xml" \
    -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    --data-binary "@${SLD_FILE}" \
    "${GEOSERVER_URL}/rest/styles/${ACTUAL_STYLE_NAME}" 2> /dev/null | tail -1)
   RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
   if [[ "${HTTP_CODE}" == "200" ]]; then
    print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' updated"
    STYLE_UPLOADED=true
   else
    print_status "${YELLOW}" "⚠️  Style '${ACTUAL_STYLE_NAME}' already exists (could not update)"
    if [[ "${FORCE_UPLOAD}" == "true" ]]; then
     STYLE_UPLOADED=true # Continue with --force
    fi
   fi
  else
   print_status "${YELLOW}" "⚠️  Style '${ACTUAL_STYLE_NAME}' already exists"
   STYLE_UPLOADED=true
  fi
 else
  print_status "${YELLOW}" "⚠️  Style upload skipped (HTTP ${HTTP_CODE})"
  if [[ "${HTTP_CODE}" == "403" ]]; then
   print_status "${YELLOW}" "   Permission denied (403 Forbidden) - Style must be created manually via web interface"
  elif [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Error:"
   echo "${RESPONSE_BODY}" | head -20 | sed 's/^/      /'
  else
   print_status "${YELLOW}" "   (No error message returned - check GeoServer logs)"
   print_status "${YELLOW}" "   Common causes:"
   print_status "${YELLOW}" "   - Invalid SLD format"
   print_status "${YELLOW}" "   - GeoServer out of memory"
   print_status "${YELLOW}" "   - File too large"
   print_status "${YELLOW}" "   - Check GeoServer logs: tail -f /opt/geoserver/logs/geoserver.log"
  fi
  # Always mark as uploaded=false when HTTP fails, but continue with installation
  # User will complete style configuration manually via web interface
  STYLE_UPLOADED=false
 fi

 rm -f "${TEMP_RESPONSE_FILE}" "${TEMP_CHECK_FILE}" 2> /dev/null || true

 # After uploading via REST API, try to copy the SLD file directly to GeoServer styles directory
 # This ensures the SLD 1.1.0 format with SvgParameter elements is preserved
 # GeoServer REST API transforms SLD 1.1.0 to 1.0.0 and loses SvgParameter elements
 if [[ "${STYLE_UPLOADED}" == "true" ]]; then
  local GEOSERVER_STYLES_DIR=""
  # Try to determine GeoServer styles directory from GEOSERVER_DATA_DIR
  if [[ -n "${GEOSERVER_DATA_DIR:-}" ]] && [[ -d "${GEOSERVER_DATA_DIR}/styles" ]]; then
   GEOSERVER_STYLES_DIR="${GEOSERVER_DATA_DIR}/styles"
  elif [[ -n "${GEOSERVER_HOME:-}" ]] && [[ -d "${GEOSERVER_HOME}/data/geoserver/styles" ]]; then
   GEOSERVER_STYLES_DIR="${GEOSERVER_HOME}/data/geoserver/styles"
  elif [[ -d "/home/geoserver/data/geoserver/styles" ]]; then
   GEOSERVER_STYLES_DIR="/home/geoserver/data/geoserver/styles"
  fi

  if [[ -n "${GEOSERVER_STYLES_DIR}" ]]; then
   local TARGET_SLD="${GEOSERVER_STYLES_DIR}/${ACTUAL_STYLE_NAME}.sld"
   local COPY_SUCCESS=false
   
   # Try to copy the SLD file directly to preserve SLD 1.1.0 format and colors
   # GeoServer REST API transforms SLD 1.1.0 to 1.0.0 and loses SvgParameter elements
   if [[ -w "${GEOSERVER_STYLES_DIR}" ]]; then
    # User has write permissions, copy directly
    if cp "${SLD_FILE}" "${TARGET_SLD}" 2>/dev/null; then
     # Try to set correct ownership if we can determine it
     if [[ -n "${GEOSERVER_USER:-geoserver}" ]] && id "${GEOSERVER_USER}" &>/dev/null; then
      chown "${GEOSERVER_USER}:${GEOSERVER_USER}" "${TARGET_SLD}" 2>/dev/null || true
     fi
     COPY_SUCCESS=true
     print_status "${GREEN}" "   ✅ SLD file copied directly to preserve colors (${ACTUAL_STYLE_NAME}.sld)"
    fi
   elif command -v sudo >/dev/null 2>&1; then
    # Try with sudo if available
    if sudo cp "${SLD_FILE}" "${TARGET_SLD}" 2>/dev/null; then
     if [[ -n "${GEOSERVER_USER:-geoserver}" ]] && id "${GEOSERVER_USER}" &>/dev/null; then
      sudo chown "${GEOSERVER_USER}:${GEOSERVER_USER}" "${TARGET_SLD}" 2>/dev/null || true
     fi
     COPY_SUCCESS=true
     print_status "${GREEN}" "   ✅ SLD file copied directly (with sudo) to preserve colors (${ACTUAL_STYLE_NAME}.sld)"
    fi
   fi
   
   if [[ "${COPY_SUCCESS}" == "false" ]]; then
    # Could not copy - show warning with instructions
    # This is important because GeoServer REST API transforms SLD 1.1.0 to 1.0.0
    # and loses SvgParameter elements (colors), making the map appear gray
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "   ⚠️  IMPORTANT: Cannot copy SLD file directly to preserve colors"
    print_status "${YELLOW}" "      GeoServer REST API transforms SLD 1.1.0 → 1.0.0 and loses SvgParameter (colors)"
    print_status "${YELLOW}" "      The map will appear GRAY until you copy the SLD files manually:"
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "      sudo cp ${SLD_FILE} ${TARGET_SLD}"
    if [[ -n "${GEOSERVER_USER:-geoserver}" ]]; then
     print_status "${YELLOW}" "      sudo chown ${GEOSERVER_USER}:${GEOSERVER_USER} ${TARGET_SLD}"
    fi
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "      Or configure sudo NOPASSWD for this directory to automate this step"
    print_status "${YELLOW}" ""
   fi
  fi
 fi

 if [[ "${STYLE_UPLOADED}" == "true" ]]; then
  return 0
 else
  return 1
 fi
}
# Function to remove a style
remove_style() {
 local STYLE_NAME="${1}"

 # Remove style (styles are global resources, not workspace-specific)
 local STYLE_URL="${GEOSERVER_URL}/rest/styles/${STYLE_NAME}"
 local TEMP_RESPONSE="${TMP_DIR}/style_delete_${STYLE_NAME}_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE}" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -X DELETE "${STYLE_URL}" 2> /dev/null | tail -1)
 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE}" 2> /dev/null || echo "")
 rm -f "${TEMP_RESPONSE}" 2> /dev/null || true

 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Style '${STYLE_NAME}' removed"
  return 0
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Style '${STYLE_NAME}' not found (already removed)"
  return 0
 else
  print_status "${YELLOW}" "⚠️  Style '${STYLE_NAME}' removal failed (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]] && [[ "${VERBOSE:-false}" == "true" ]]; then
   print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -3 | tr '\n' ' ')"
  fi
  return 1
 fi
}
