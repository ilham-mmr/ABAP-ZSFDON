FUNCTION z_didsd_bapi_sf_do_gen.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  EXPORTING
*"     VALUE(RETURN) TYPE  BAPIRET2
*"  TABLES
*"      IT_DO_NUM STRUCTURE  ZDIDSDS037
*"      IT_FEEDH STRUCTURE  ZDIDSDS035
*"      IT_FEEDD STRUCTURE  ZDIDSDS036
*"  EXCEPTIONS
*"      GET_LIST_ERROR
*"----------------------------------------------------------------------
  DATA: ls_return TYPE bapiret2.

  DATA: lt_zdidsdt005 TYPE STANDARD TABLE OF zdidsdt005,
        lt_zdidsdt006 TYPE STANDARD TABLE OF zdidsdt006.


  DATA: lv_date TYPE sy-datum,
        lv_time TYPE sy-uzeit.

  DATA: lv_log_id    TYPE num10.

  lv_date = sy-datum.
  lv_time = sy-uzeit.


  CLEAR: it_feedh,
         it_feedd,
         return.
  ls_return-id = '00'.  " Message class
  ls_return-number = '208'.  " Message number


  TRY.

      IF it_do_num[] IS INITIAL.
        ls_return-type = 'E'.
        ls_return-message = 'Parameter it_do_num should not be empty'.
        return = ls_return.
        RETURN.  " Exi
      ENDIF.

      LOOP AT it_do_num.
        r_vbeln-sign = 'I'.
        r_vbeln-option = 'EQ'.
        r_vbeln-low = it_do_num-vbeln.
        APPEND r_vbeln.
      ENDLOOP.

      SELECT   a~vbeln,   "do
               a~bldat,
               a~kodat,
               a~lddat,
               a~wadat_ist,
               a~lstel,
               a~lfdat,
               a~vstel,
               a~vsbed,
               a~vsart,
               a~lfart,
               a~kunag,
               a~kunnr,
               a~knkli,
               a~zzsjreceipt,
               a~zzsjarrvdat,
               a~berot,
               b~posnr,
               b~matnr,
               b~lfimg,
               b~meins,
               b~lgort,
               b~vgpos,
               b~vgbel " so
        FROM likp AS a
        INNER JOIN lips AS b ON a~vbeln EQ b~vbeln
        WHERE
           a~lfart NE @c_el_delivery_type
          AND a~vbeln IN @r_vbeln
        INTO CORRESPONDING FIELDS OF TABLE @it_deliv.


      IF it_deliv[] IS INITIAL.
        ls_return-type = 'W'.  " Error type
        ls_return-message = 'Data Not Found'.  " Message text
        return = ls_return.
        RETURN.  " Exit the BAPI
      ENDIF.


* Get data for So
      SELECT *
           FROM vbap
        FOR ALL ENTRIES IN @it_deliv
      WHERE vbeln EQ @it_deliv-vgbel
        INTO CORRESPONDING FIELDS OF TABLE @it_vbap.


*  Get Header Delivery
      SELECT vbeln, erdat, aedat
        FROM likp
        FOR ALL ENTRIES IN @it_deliv
        WHERE vbeln EQ @it_deliV-vbeln
        INTO CORRESPONDING FIELDS OF TABLE @it_likp.

* Complete data
      LOOP AT it_deliv INTO wa_deliv.
        SELECT SINGLE vtweg,
                      spart
                FROM vbak
                INTO (@wa_deliv-vtweg, @wa_deliv-spart)
          WHERE vbeln EQ @wa_deliv-vgbel.

        SELECT SINGLE ihrez_e
               FROM vbkd
               INTO @wa_deliv-ihrez_e
         WHERE vbeln EQ @wa_deliv-vgbel.

        MODIFY it_deliv FROM wa_deliv.
      ENDLOOP.

      DELETE it_deliv WHERE  ihrez_e = space.
      DESCRIBE TABLE it_deliv LINES DATA(table_n).
      IF table_n EQ 0.
        ls_return-type = 'W'.
        ls_return-message = 'No entries found where ihrez_e field contains data'.
        return = ls_return.
        RETURN.  " Exit the BAPI
      ENDIF.




* PROCESS DETAIL PART(IT_FEEDD)
      SORT it_vbap BY vbeln posnr.
      SORT it_deliv BY vgbel vgpos.
      LOOP AT it_DELIV INTO wa_deliv.
        it_feedd-item_line_sap__c = wa_deliv-posnr.
        it_feedd-material__c = wa_deliv-matnr.
        it_feedd-quantity = wa_deliv-lfimg.
        it_feedd-storage_loct__c = wa_deliv-lgort.
        it_feedd-reference_doc__c = wa_deliv-vgpos.
        it_feedd-reference_item__c = wa_deliv-vgbel.
        it_feedd-do_number_sap__c = wa_deliv-vbeln.
        it_feedd-quotation_number__c = wa_deliv-ihrez_e.


        READ TABLE it_vbap INTO wa_vbap WITH KEY vbeln = it_feedd-reference_item__c
                                                 posnr = it_feedd-item_line_sap__c BINARY SEARCH.
        IF sy-subrc EQ 0.
          it_feedd-Material_BOM__c = wa_vbap-upmat.
        ELSE.
          it_feedd-Material_BOM__c = space.
        ENDIF.

        SHIFT it_feedd-item_line_sap__c LEFT DELETING LEADING '0'.
        SHIFT it_feedd-reference_doc__c LEFT DELETING LEADING '0'.

        REPLACE ALL OCCURRENCES OF '.000' IN it_feedd-quantity WITH ''.
        CONDENSE it_feedd-quantity.

        it_feedd-DO_Line_External_Key__c = |{ it_feedd-do_number_sap__c }{ it_feedd-material__c }{ it_feedd-reference_doc__c }|.


        APPEND it_feedd.
      ENDLOOP.
* PROCESS HEADER PART(IT_FEEDH)
      SORT it_deliv BY vbeln.
      DELETE ADJACENT DUPLICATES FROM it_deliv COMPARING vbeln.
      LOOP AT it_deliv INTO wa_deliv.

        it_feedh-dates__c = wa_deliv-bldat.
        it_feedh-pick_deadline__c = wa_deliv-kodat.
        it_feedh-Loading_date__c = wa_deliv-lddat.
        it_feedh-GI_Actual_Date__c = wa_deliv-wadat_ist.
        it_feedh-Loading_Point__c = wa_deliv-lstel.
        it_feedh-Delivery_date__c = wa_deliv-lfdat.
        it_feedh-shpg_cond__c = wa_deliv-vsbed.
        it_feedh-delivery_type__c = wa_deliv-lfart.
        it_feedh-req_arrvial_date__c = wa_deliv-zzsjarrvdat.
        it_feedh-quotation_number__c = wa_deliv-ihrez_e.
        it_feedh-do_number_sap__c = wa_deliv-vbeln.
        it_feedh-reference_doc__c = wa_deliv-vgbel.

        it_feedh-dates__c = |{ it_feedh-dates__c(4) }-{ it_feedh-dates__c+4(2) }-{ it_feedh-dates__c+6(2) } { c_seven_hour }|.
        it_feedh-pick_deadline__c = |{ it_feedh-pick_deadline__c(4) }-{ it_feedh-pick_deadline__c+4(2) }-{ it_feedh-pick_deadline__c+6(2) } { c_seven_hour }|.
        it_feedh-Loading_date__c = |{ it_feedh-Loading_date__c(4) }-{ it_feedh-Loading_date__c+4(2) }-{ it_feedh-Loading_date__c+6(2) } { c_seven_hour }|.

*
        IF it_feedh-GI_Actual_Date__c = '00000000' OR  it_feedh-GI_Actual_Date__c IS INITIAL .
          CLEAR it_feedh-GI_Actual_Date__c.
        ELSE.
          it_feedh-GI_Actual_Date__c = |{ it_feedh-GI_Actual_Date__c(4) }-{ it_feedh-GI_Actual_Date__c+4(2) }-{ it_feedh-GI_Actual_Date__c+6(2) } { c_seven_hour }|.
        ENDIF.

        it_feedh-Delivery_date__c = |{ it_feedh-Delivery_date__c(4) }-{ it_feedh-Delivery_date__c+4(2) }-{ it_feedh-Delivery_date__c+6(2) } { c_seven_hour }|.
        it_feedh-req_arrvial_date__c = |{ it_feedh-req_arrvial_date__c(4) }-{ it_feedh-req_arrvial_date__c+4(2) }-{ it_feedh-req_arrvial_date__c+6(2) } { c_seven_hour }|.


        it_feedh-DO_Number_External_Key__c = it_feedh-DO_Number_SAP__c.
        APPEND it_feedh.
      ENDLOOP.

      lt_zdidsdt005 = VALUE #( FOR ls_feedh IN it_feedh
                         ( CORRESPONDING #( ls_feedh )  ) ).


      lt_zdidsdt006 = VALUE #( FOR ls_feedd IN it_feedd
                        ( CORRESPONDING #( ls_feedd ) ) ).



      LOOP AT lt_zdidsdt005 ASSIGNING FIELD-SYMBOL(<ls_zdidsdt005>).
        lv_log_id = lv_log_id + 1.
        <ls_zdidsdt005>-line_no = lv_log_id.
        <ls_zdidsdt005>-executed_date = lv_date.
        <ls_zdidsdt005>-executed_time = lv_time.
      ENDLOOP.

      CLEAR:lv_log_id.

      LOOP AT lt_zdidsdt006 ASSIGNING FIELD-SYMBOL(<ls_zdidsdt006>).
        lv_log_id = lv_log_id + 1.
        <ls_zdidsdt006>-line_no = lv_log_id.
        <ls_zdidsdt006>-executed_date = lv_date.
        <ls_zdidsdt006>-executed_time = lv_time.
      ENDLOOP.

      INSERT zdidsdt005 FROM TABLE lt_zdidsdt005 ACCEPTING DUPLICATE KEYS.
      IF sy-subrc = 4.
        ls_return-type = 'W'.
        ls_return-message = 'Duplicate keys when updating log to table zdidsdt005'.
        return = ls_return.
        RETURN.
      ENDIF.

      INSERT zdidsdt006 FROM TABLE lt_zdidsdt006 ACCEPTING DUPLICATE KEYS.
      IF sy-subrc = 4.
        ls_return-type = 'W'.
        ls_return-message = 'Duplicate keys when updating log to table zdidsdt006'.
        return = ls_return.
        RETURN.
      ENDIF.


      DESCRIBE TABLE it_feedh LINES DATA(table_n1).
      DESCRIBE TABLE it_feedd LINES DATA(table_n2).

      IF table_n1 EQ 0 OR table_n2 EQ 0.
        ls_return-type = 'W'.  "
        ls_return-message = 'No result found for it_feedh or it_feedd'.
        return = ls_return.
        RETURN.  " Exit the BAPI
      ELSE.
        ls_return-type = 'S'.
        ls_return-message = 'Result found'.  " Message text
        return = ls_return.
        RETURN.  " Exit the BAPI
      ENDIF.

    CATCH cx_root INTO DATA(lx_root) .
      ls_return-type = 'E'.  " Error type
      ls_return-message = |Unexpected error occured: { lx_root->get_text( ) } |.
      return = ls_return.
  ENDTRY.
ENDFUNCTION.
