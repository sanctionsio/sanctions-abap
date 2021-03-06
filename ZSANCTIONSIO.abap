*&---------------------------------------------------------------------*
*&   _____  ______ __  __ ______ _______     ___   _ ______
*&  |  __ \|  ____|  \/  |  ____|  __ \ \   / / \ | |  ____|
*&  | |__) | |__  | \  / | |__  | |  | \ \_/ /|  \| | |__
*&  |  _  /|  __| | |\/| |  __| | |  | |\   / | . ` |  __|
*&  | | \ \| |____| |  | | |____| |__| | | |  | |\  | |____
*&  |_|  \_\______|_|  |_|______|_____/  |_|  |_| \_|______|
*&
*&   _____                  _   _                   _
*&  / ____|                | | (_)                 (_)
*& | (___   __ _ _ __   ___| |_ _  ___  _ __  ___   _  ___
*&  \___ \ / _` | '_ \ / __| __| |/ _ \| '_ \/ __| | |/ _ \
*&  ____) | (_| | | | | (__| |_| | (_) | | | \__ \_| | (_) |
*& |_____/ \__,_|_| |_|\___|\__|_|\___/|_| |_|___(_)_|\___/
*&
*&  Author: Rodrigo Giner de la Vega
*&---------------------------------------------------------------------*

REPORT  zsanctionsio.

* Declarations
TYPE-POOLS: vrm.

DATA: name          TYPE vrm_id,
      list          TYPE vrm_values,
      value         LIKE LINE OF list,
      lv_name(120)  TYPE c,
      lv_index      TYPE i,
      gv_matches    TYPE i.

DATA: docking         TYPE REF TO cl_gui_docking_container,
      lo_html_viewer  TYPE REF TO cl_gui_html_viewer.

DATA: v_path TYPE string,
      lo_http_client TYPE REF TO if_http_client,
      lv_response TYPE string,
      lt_responsetable TYPE TABLE OF string,
      lv_count TYPE i,
      lv_lines TYPE i.

DATA: BEGIN OF gt_data OCCURS 0,
        name TYPE char120,
      END OF gt_data.
DATA: gs_data LIKE LINE OF gt_data.

TYPES: BEGIN OF t_alv,
        entity_num  TYPE i,
        search      TYPE char120,
        name        TYPE char120,
      END OF t_alv.
DATA: gt_alv TYPE TABLE OF t_alv.
DATA: gs_alv LIKE LINE OF gt_alv.

FIELD-SYMBOLS: <gs_data> TYPE ANY,
               <gt_data> TYPE STANDARD TABLE.

* Selection Screen
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME.
PARAMETERS: p_api TYPE string OBLIGATORY LOWER CASE,
            p_dest(20) OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME.
PARAMETERS: p_table TYPE string,
            p_field TYPE string.
SELECT-OPTIONS: so_name FOR lv_name NO-EXTENSION NO INTERVALS.
PARAMETERS: p_list(10) AS LISTBOX VISIBLE LENGTH 50.
SELECTION-SCREEN END OF BLOCK b2.

AT SELECTION-SCREEN OUTPUT.
  name = 'P_LIST'.
  value-key = 'CFSP'. value-text = 'Consolidated list of sanctions (CFSP)'.                             APPEND value TO list.
  value-key = 'UN'.   value-text = 'Consolidated United Nations Security Council Sanctions List (UN)'.  APPEND value TO list.
  value-key = 'HMT'.  value-text = 'Consolidated list of targets (HMT)'.                                APPEND value TO list.
  value-key = 'DPL'.  value-text = 'Denied Persons List (DPL)'.                                         APPEND value TO list.
  value-key = 'UL'.   value-text = 'Unverified List (UL)'.                                              APPEND value TO list.
  value-key = 'EL'.   value-text = 'Entity List (EL)'.                                                  APPEND value TO list.
  value-key = 'ISN'.  value-text = 'Nonproliferation Sanctions (ISN)'.                                  APPEND value TO list.
  value-key = 'DTC'.  value-text = 'ITAR Debarred (DTC)'.                                               APPEND value TO list.
  value-key = 'SDN'.  value-text = 'Specially Designated Nationals List (SDN)'.                         APPEND value TO list.
  value-key = 'FSE'.  value-text = 'Foreign Sanctions Evaders List (FSE)'.                              APPEND value TO list.
  value-key = 'SSI'.  value-text = 'Sectoral Sanctions Identifications List (SSI)'.                     APPEND value TO list.
  value-key = 'PLC'.  value-text = 'Non-SDN Palestinian Legislative Council List (PLC)'.                APPEND value TO list.
  value-key = '561'.  value-text = 'Foreign Financial Institutions Subject to Part 561 (561)'.          APPEND value TO list.
  value-key = 'NS-ISA'. value-text = 'Non-SDN Iranian Sanctions Act List (NS-ISA)'.                     APPEND value TO list.

  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = name
      values = list.

  PERFORM show_web_page.

AT SELECTION-SCREEN.
  IF p_table IS INITIAL AND so_name[] IS INITIAL.
    MESSAGE 'Please enter Table and Field or Name to search' TYPE 'E'.
  ENDIF.

  IF p_table IS INITIAL AND p_field IS NOT INITIAL AND so_name[] IS INITIAL.
    MESSAGE 'Please enter a table' TYPE 'E'.
  ELSE.
    IF p_field IS INITIAL AND so_name[] IS INITIAL.
      MESSAGE 'Please enter a field of table entered' TYPE 'E'.
    ELSE.
      DATA: lt_dfies_tab TYPE STANDARD TABLE OF dfies,
            lv_table     TYPE ddobjname.

      lv_table = p_table.
      CALL FUNCTION 'DDIF_FIELDINFO_GET'
        EXPORTING
          tabname        = lv_table
        TABLES
          dfies_tab      = lt_dfies_tab
        EXCEPTIONS
          not_found      = 1
          internal_error = 2
          OTHERS         = 3.
      IF sy-subrc <> 0 AND so_name[] IS INITIAL.
        MESSAGE 'Please enter a valid table' TYPE 'E'.
      ENDIF.
    ENDIF.
  ENDIF.

START-OF-SELECTION.
* Select Data (if table and field used)
  PERFORM get_data.

  DESCRIBE TABLE gt_data LINES lv_lines.
  LOOP AT gt_data INTO gs_data.
    lv_index = lv_index + 1.
    PERFORM call_api CHANGING gs_data-name
                              p_list
                              gt_alv.

    PERFORM progress_bar USING 'Processig data...'(001)
                               lv_index
                               lv_lines.
  ENDLOOP.

  SORT gt_alv BY entity_num search name.
  DELETE ADJACENT DUPLICATES FROM gt_alv COMPARING ALL FIELDS.
  LOOP AT gt_alv INTO gs_alv.
    AT NEW entity_num.
      gv_matches = gv_matches + 1.
    ENDAT.
  ENDLOOP.

END-OF-SELECTION.

* Show ALV
  PERFORM show_alv.
*&---------------------------------------------------------------------*
*&      Form  GET_DATA
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM get_data .
  DATA: lo_type_desc    TYPE REF TO cl_abap_typedescr, "cl_abap_elemdescr,
        lo_field_type   TYPE REF TO cl_abap_elemdescr,
        lv_field_aux    TYPE string,
        ls_field_descr  TYPE abap_componentdescr, "cl_abap_structdescr=>component,
        lt_field_descr  TYPE abap_component_tab,
        lt_key_descr    TYPE abap_component_tab,
        lo_field_struct TYPE REF TO cl_abap_structdescr,
        lo_field_ref    TYPE REF TO data,
        lo_tabledescr   TYPE REF TO cl_abap_tabledescr,
        lo_table_ref    TYPE REF TO data.

  IF p_table IS NOT INITIAL AND p_field IS NOT INITIAL.
    SELECT (p_field)
      FROM (p_table)
      INTO TABLE gt_data.

    DELETE gt_data WHERE name NOT IN so_name.
  ELSE.
    gs_data-name = so_name-low.
    APPEND gs_data TO gt_data.
  ENDIF.

ENDFORM.                    " GET_DATA
*&---------------------------------------------------------------------*
*&      Form  CALL_API
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GS_DATA_NAME  text
*      <--P_GT_ALV  text
*----------------------------------------------------------------------*
FORM call_api  CHANGING p_name
                        p_list
                        t_alv.

  DATA lv_count_api TYPE i.
  DATA lv_fuzzy TYPE string.
  DATA: lv_text_aux TYPE string.
  DATA: result_tab TYPE match_result_tab.
  DATA: result_tab_entity TYPE match_result_tab.
  DATA: result_tab_alt_names TYPE match_result_tab.
  DATA: result_tab_names TYPE match_result_tab.
  DATA: ls_result_tab LIKE LINE OF result_tab.
  DATA: BEGIN OF ls_matches,
          offset TYPE i,
          length TYPE i,
        END OF ls_matches.

  CLEAR: lo_http_client, gs_alv.

  cl_http_client=>create_by_destination(
    EXPORTING
      destination              = p_dest
    IMPORTING
      client                   = lo_http_client
    EXCEPTIONS
      argument_not_found       = 1
      destination_not_found    = 2
      destination_no_authority = 3
      plugin_not_active        = 4
      internal_error           = 5
      OTHERS                   = 6 ).
  IF sy-subrc <> 0.
    WRITE: 'create error', sy-subrc.
  ENDIF.

  DATA: emptybuffer TYPE xstring.
  emptybuffer = ''.
  CALL METHOD lo_http_client->request->set_data
    EXPORTING
      data = emptybuffer.

  CALL METHOD lo_http_client->request->set_header_field
    EXPORTING
      name  = '~request_method'
      value = 'GET'.

  CALL METHOD lo_http_client->request->set_header_field
    EXPORTING
      name  = 'Content-Type'
      value = 'text/xml; charset=utf-8'.

  CALL METHOD lo_http_client->request->set_header_field
    EXPORTING
      name  = 'Accept'
      value = 'text/xml, text/html, application/json, text/csv'.

  IF p_name CS '*'.
    lv_fuzzy = '&fuzzy_name=true'.
  ENDIF.
  TRANSLATE p_name USING ' +'.
  SHIFT p_name RIGHT DELETING TRAILING `+`.
  TRANSLATE p_name USING '*+'.
  CONDENSE p_name NO-GAPS.
  CONCATENATE '/search/?api_key=' p_api `&name=` p_name lv_fuzzy `&sources=` p_list INTO v_path.

  cl_http_utility=>set_request_uri( request = lo_http_client->request
                                     uri    = v_path ).

  lo_http_client->request->set_method(
                     if_http_request=>co_request_method_get ).

  lo_http_client->send(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state         = 2
      http_processing_failed     = 3
      http_invalid_timeout       = 4
      OTHERS                     = 5 ).

  IF sy-subrc <> 0.
    WRITE: 'send error', sy-subrc.
  ENDIF.

  lo_http_client->receive(
    EXCEPTIONS
      http_communication_failure = 1
      http_invalid_state         = 2
      http_processing_failed     = 3
      OTHERS                     = 4 ).
  DATA: subrc LIKE sy-subrc.

  IF sy-subrc <> 0.
    WRITE: 'receive error', sy-subrc.
    CALL METHOD lo_http_client->get_last_error
      IMPORTING
        code    = subrc
        MESSAGE = lv_response.
    WRITE: / 'communication_error( receive )',
           / 'code: ', subrc, 'message: ', lv_response.
    CLEAR lv_response.
  ENDIF.

  lv_response = lo_http_client->response->get_cdata( ).

  lo_http_client->close( ).

*Check Count
  FIND REGEX `"count":([0-9]+)` IN lv_response RESULTS result_tab.

  LOOP AT result_tab INTO ls_result_tab.
    LOOP AT ls_result_tab-submatches INTO ls_matches WHERE offset >= 0.
      lv_count_api = lv_response+ls_matches-offset(ls_matches-length).
    ENDLOOP.
  ENDLOOP.
  IF sy-subrc <> 0.
    MESSAGE 'Could not connect to the API, check you API Key and try again.' TYPE 'I'.
    SUBMIT ZSANCTIONSIO VIA SELECTION-SCREEN WITH p_table = p_table
                                             WITH p_field = p_field
                                             WITH p_api   = p_api
                                             WITH p_dest  = p_dest
                                             WITH so_name = so_name-low.
  ENDIF.

  IF NOT lv_count_api > 0.
    EXIT.
  ENDIF.

*Entity_number
  FIND ALL OCCURRENCES OF REGEX `"entity_number":([0-9]+)` IN lv_response RESULTS result_tab_entity.

  DATA gv_index TYPE i.
  LOOP AT result_tab_entity INTO ls_result_tab.
    CLEAR gs_alv.
    gv_index = gv_index + 1.
    LOOP AT ls_result_tab-submatches INTO ls_matches WHERE offset >= 0.
      gs_alv-entity_num = lv_response+ls_matches-offset(ls_matches-length).
    ENDLOOP.

*  Alternative names
    FIND ALL OCCURRENCES OF REGEX `"alt_names":\["([^"]*)"(?:,"([^"]*)"(?:,"([^"]*)"(?:,"([^"]*)"(?:,"([^"]*)")?)?)?)?` IN lv_response RESULTS result_tab_alt_names.

    LOOP AT result_tab_alt_names INTO ls_result_tab FROM gv_index TO gv_index.
      LOOP AT ls_result_tab-submatches INTO ls_matches WHERE offset >= 0.
        "WRITE: /, lv_response+ls_matches-offset(ls_matches-length).
        gs_alv-search = p_name.
        gs_alv-name = lv_response+ls_matches-offset(ls_matches-length).
        APPEND gs_alv TO gt_alv.
      ENDLOOP.
    ENDLOOP.

*  Name
    FIND ALL OCCURRENCES OF REGEX `"name":"(\\"|[^"]*)"` IN lv_response RESULTS result_tab_names.

    LOOP AT result_tab_names INTO ls_result_tab FROM gv_index TO gv_index.
      LOOP AT ls_result_tab-submatches INTO ls_matches WHERE offset >= 0.
        gs_alv-search = p_name.
        gs_alv-name   = lv_response+ls_matches-offset(ls_matches-length).
        APPEND gs_alv TO gt_alv.
        "WRITE: /, lv_response+ls_matches-offset(ls_matches-length).
      ENDLOOP.
    ENDLOOP.
  ENDLOOP.

ENDFORM.                    " CALL_API
*&---------------------------------------------------------------------*
*&      Form  SHOW_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM show_alv .

*ALV reference
  DATA: o_alv TYPE REF TO cl_salv_table.
  DATA: lx_msg TYPE REF TO cx_salv_msg.

  TRY.
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = o_alv
        CHANGING
          t_table      = gt_alv ).
    CATCH cx_salv_msg INTO lx_msg.
  ENDTRY.

  DATA: lo_header  TYPE REF TO cl_salv_form_layout_grid,
        lo_h_label TYPE REF TO cl_salv_form_label,
        lo_h_flow  TYPE REF TO cl_salv_form_layout_flow.

*Header
  CREATE OBJECT lo_header.

  lo_h_label = lo_header->create_label( row = 1 column = 1 ).
  lo_h_label->set_text( 'Searches Found:' ).

  lo_h_label = lo_header->create_label( row = 1 column = 2 ).
  lo_h_label->set_text( gv_matches ).
  o_alv->set_top_of_list( lo_header ).

* Status
  DATA: lo_functions TYPE REF TO cl_salv_functions_list.

  lo_functions = o_alv->get_functions( ).
  lo_functions->set_all( abap_true ).

* Display
  DATA: lo_display TYPE REF TO cl_salv_display_settings.

  lo_display = o_alv->get_display_settings( ).
  lo_display->set_striped_pattern( 'X' ).
  lo_display->set_list_header( 'SANCTIONS.IO - Matches found' ).

* Layout
  DATA: lo_layout  TYPE REF TO cl_salv_layout,
        lf_variant TYPE slis_vari,
        ls_key    TYPE salv_s_layout_key.

  lo_layout = o_alv->get_layout( ).

  ls_key-report = sy-repid.
  lo_layout->set_key( ls_key ).
  lo_layout->set_save_restriction( if_salv_c_layout=>restrict_user_dependant ).

  lf_variant = 'DEFAULT'.
  lo_layout->set_initial_layout( lf_variant ).

* Catalog
  DATA: lo_cols TYPE REF TO cl_salv_columns_table.

  lo_cols = o_alv->get_columns( ).
  lo_cols->set_optimize( ).
  lo_cols->set_key_fixation( ).

  DATA: lo_column TYPE REF TO cl_salv_column_table.
  TRY.
      lo_column ?= lo_cols->get_column( 'ENTITY_NUM' ).
      lo_column->set_short_text( 'Ent.Number' ).
      lo_column->set_medium_text( 'Ent. Number' ).
      lo_column->set_long_text( 'Entity Number' ).

      lo_column ?= lo_cols->get_column( 'SEARCH' ).
      lo_column->set_key_presence_required( ).
      lo_column->set_short_text( 'Search' ).
      lo_column->set_medium_text( 'Search' ).
      lo_column->set_long_text( 'Search' ).

      lo_column ?= lo_cols->get_column( 'NAME' ).
      lo_column->set_short_text( 'Names' ).
      lo_column->set_medium_text( 'Names' ).
      lo_column->set_long_text( 'Names' ).
    CATCH cx_salv_not_found.                            "#EC NO_HANDLER
  ENDTRY.

  o_alv->display( ).

ENDFORM.                    " SHOW_ALV
*&---------------------------------------------------------------------*
*&      Form  PROGRESS_BAR
*&---------------------------------------------------------------------*
FORM progress_bar USING    p_value
                           p_tabix
                           p_nlines.
  DATA: w_text(40),
        w_percentage TYPE p,
        gd_percent TYPE p,
        w_percent_char(3).
  w_percentage = ( p_tabix / p_nlines ) * 100.
  w_percent_char = w_percentage.
  SHIFT w_percent_char LEFT DELETING LEADING ' '.
  CONCATENATE p_value w_percent_char '% Complete'(002) INTO w_text.

  IF w_percentage GT gd_percent OR p_tabix EQ 1.
    CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
      EXPORTING
        percentage = w_percentage
        text       = w_text.
    gd_percent = w_percentage.
  ENDIF.
ENDFORM.                    " PROGRESS_BAR
*&---------------------------------------------------------------------*
*& Form show_web_page
*&---------------------------------------------------------------------*
FORM show_web_page.

  DATA: repid LIKE sy-repid.
  repid = sy-repid.
  DATA: lt_html TYPE TABLE OF w3_html,
        ls_html LIKE LINE OF lt_html.
  DATA: lv_url(80).

  IF docking IS INITIAL .
*  Create objects for the reference variables
    CREATE OBJECT docking
      EXPORTING
        repid                       = repid
        dynnr                       = sy-dynnr
        side                        = cl_gui_docking_container=>dock_at_right
        ratio                       = 60
      EXCEPTIONS
        cntl_error                  = 1    "extension = '600'
        cntl_system_error           = 2
        create_error                = 3
        lifetime_error              = 4
        lifetime_dynpro_dynpro_link = 5.


    CREATE OBJECT lo_html_viewer
      EXPORTING
        parent = docking.
    CHECK sy-subrc = 0.

    ls_html = '<html><body><div>ZSANCTIONSIO is a template SAP ABAP report that implements the <a href="http://sanctions.io" target="_blank">sanctions.io</a>'.
    APPEND ls_html TO lt_html.
    ls_html = ` (<a href="https://sanctions.io" target="_blank">https://sanctions.io</a>) API to check persons and organizations against sanction lists.</div><div><br></div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div>To learn more about supported sanction lists and the API, visit <a href="https://sanctions.io" target="_blank">https://sanctions.io</a></div><div>`.
    APPEND ls_html TO lt_html.
    ls_html = `This report does not implement advanced features of the API like fuzzy search, matching country or date of birth, etc.</div><div><br></div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div>This report is provided as is and with no warranty under the 3-clause-BSD license, see&nbsp;<a href="https://opensource.org/licenses/BSD-3-Clause"`.
    APPEND ls_html TO lt_html.
    ls_html = `target="_blank">https://opensource.org/<wbr>licenses/BSD-3-Clause</a>.</div><div>Redistribution and use, with or without modification, is permitted.</div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div>Copyright 2019 REMEDYNE GmbH.</div><div><br></div><div>Before using this report:</div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div>1. Create an RFC destination as described here:</div><div><a href="https://remedyne.help/knowledgebase/configure-ssl-client-for-sanction-list-screening/"`.
    APPEND ls_html TO lt_html.
    ls_html = `target="_blank">https://remedyne.help/<wbr>knowledgebase/configure-ssl-<wbr>client-for-sanction-list-<wbr>screening/</a></div><div>2. Sign-up for an API key on`.
    APPEND ls_html TO lt_html.
    ls_html = `<a href="https://sanctions.io" target="_blank">https://sanctions.io</a>. A free trial is available.</div><div>`.
    APPEND ls_html TO lt_html.
    ls_html = `3. This report does not perform an AUTHORITY-CHECK when executed: make sure you apply appropriate security mechanisms before deploying this.</div><div>`.
    APPEND ls_html TO lt_html.
    ls_html = `4. This template report comes with no warranty. It has been used in several environments without problems, but running this check against large sets of data`.
    APPEND ls_html TO lt_html.
    ls_html = `can have an impact on the performance of your SAP system.</div><div><br></div><div>To use this report:</div><div>Enter a table name and field name that`.
    APPEND ls_html TO lt_html.
    ls_html = `contains names, e.g. business partner names such as LFA1:NAME1, and select the sanction list against which you want to run the check.</div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div>You can also enter a name and check whether the name is on a list.</div><div><br></div><div>In case of questions, contact`.
    APPEND ls_html TO lt_html.
    ls_html = `<a href="mailto:info@sanctions.io" target="_blank">info@sanctions.io</a></div><div><br></div><div><br></div>`.
    APPEND ls_html TO lt_html.
    ls_html = `<div><br></div><div><img id="image" src="https://github.com/REMEDYNE/Sanctions.io/blob/master/sanctions.io_transparent_small.png?raw=true" data-image-whitelisted=""></div>`.
    APPEND ls_html TO lt_html.
    ls_html = `</body></html>`.
    APPEND ls_html TO lt_html.

    CALL METHOD lo_html_viewer->load_data
      IMPORTING
        assigned_url = lv_url
      CHANGING
        data_table   = lt_html.
* Load Web Page using url from selection screen.
    IF sy-subrc = 0.
      CALL METHOD lo_html_viewer->show_url
        EXPORTING
          url = lv_url.
    ENDIF.
  ENDIF .

ENDFORM.                    "show_web_page
