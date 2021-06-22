CREATE OR REPLACE package body MEDICARE.k_opd
as

procedure pd_gen_app_slot (
      p_doc_no                  in number,
      p_app_date                in date,
      p_shift_no                in number,
      p_start_time              in date,
      p_end_time                in date,
      p_no_of_load              in number,
      p_ss_creator              in number,
      p_og_no                   in number,
      p_company_no              in number,
      p_ss_created_session      in number,
      p_error                   out varchar
   )
   as
      v_time_diff      number;
      
      v_avg_slot_dur   number;            
      v_remain_time    number;
      v_slot_dur       number;
      v_start_min      number;
      v_slot_no        number;
      v_gen_slot_no    number;

begin
      
    if p_start_time is not null and p_end_time is not null then
          
        v_time_diff := (to_number (to_char (p_end_time, 'hh24')) * 60 + to_number (to_char (p_end_time, 'mi')))
                     - (to_number (to_char (p_start_time, 'hh24')) * 60 + to_number (to_char (p_start_time, 'mi')));
        
        v_avg_slot_dur := floor (v_time_diff / nvl (p_no_of_load, 1));
        
        v_remain_time := mod (v_time_diff, nvl (p_no_of_load, 1));

        for i in 1 .. nvl (p_no_of_load, 1) loop
                        
            if i = p_no_of_load then  
               v_slot_dur := v_avg_slot_dur - 1 + v_remain_time;
            elsif i - 1 > 0 then
               v_slot_dur := v_avg_slot_dur - 1;
            else
               v_slot_dur := v_avg_slot_dur;
            end if;

            if i - 1 > 0 then      
               v_start_min := (v_avg_slot_dur * (i - 1)) + 1;   
            else
               v_start_min := 0;
            end if;
            
            pd_ins_app_slot (p_doc_no                  => p_doc_no,
                             p_app_date                => p_app_date,
                             p_shift_no                => p_shift_no,
                             p_start_time              => k_general.fd_add_daytime (p_start_time, 0, 0, v_start_min, 0),
                             p_end_time                => k_general.fd_add_daytime (p_start_time, 0, 0, v_start_min, 0),
                             p_duration                => v_slot_dur,
                             p_extra_slot              => 0,
                             p_slot_sl                 => v_slot_no,
                             p_ss_creator              => p_ss_creator,
                             p_og_no                   => p_og_no,
                             p_company_no              => p_company_no,
                             p_ss_created_session      => p_ss_created_session,
                             p_slot_no                 => v_gen_slot_no,
                             p_error                   => p_error
                             );

            
            
        end loop;
    
    end if;
    
exception when others then
     p_error := sqlerrm;
end pd_gen_app_slot;

procedure pd_ins_app_slot (
      p_doc_no                  in number,
      p_app_date                in date,
      p_shift_no                in number,
      p_start_time              in date,
      p_end_time                in date,
      p_duration                in number,
      p_extra_slot              in number,
      p_slot_sl                 in number,
      p_ss_creator              in number,
      p_og_no                   in number,
      p_company_no              in number,
      p_ss_created_session      in number,
      p_slot_no                 out number,
      p_error                   out varchar
   )
   as
      cursor cur_time_chk (p_time date)
      is
         select count (slot_no)
           from opd_appointment_slot
          where p_time between start_time
          and k_general.fd_add_daytime (start_time, 0, 0, duration_min, 0)
            and trunc (slot_date) = trunc (p_app_date)
            and doctor_no = p_doc_no;

      cursor cur_max_sl (p_time date)
      is
         select max (slot_sl)
           from opd_appointment_slot
          where doctor_no = p_doc_no
            and start_time < p_time
            and trunc (slot_date) = trunc (p_app_date)
            and shiftdtl_no = p_shift_no;

      v_check_st    number := 0;
      v_check_en    number := 0;
      v_slot_sl     number := 0;
      v_pk          number;
      v_slot_status number := 0;
      
      cursor c_autho_slot (p_sl number)
      is
      select count(preserv_sl) preserv_sl
      from hpms_doc_app_sl_authority
      where doctor_no = p_doc_no
      and shift_dtl_no = p_shift_no
      and week_day = ltrim(rtrim(to_char(p_app_date,'DAY')))
      and preserv_sl = p_sl;
      
      v_preserv_sl number := 0;
       
   begin
      
      if p_doc_no is null then
         return;
      end if;

      open cur_time_chk (p_start_time);

      fetch cur_time_chk
       into v_check_st;

      close cur_time_chk;

      open cur_time_chk (k_general.fd_add_daytime (p_start_time, 0, 0, p_duration, 0));

      fetch cur_time_chk
       into v_check_en;

      close cur_time_chk;

      if v_check_st <= 0 and v_check_en <= 0
      then
         if nvl (p_slot_sl, 0) > 0
         then
            v_slot_sl := p_slot_sl;
         else
            open cur_max_sl (p_start_time);

            fetch cur_max_sl
             into v_slot_sl;

            close cur_max_sl;

            v_slot_sl := nvl(v_slot_sl,0) + 1;
         
         end if;

         k_general.pd_genarate_no ('SEQ_SLOT_NO', p_company_no, v_pk);
         
         open c_autho_slot(v_slot_sl); fetch c_autho_slot into v_preserv_sl; close c_autho_slot;
         
         if v_preserv_sl = 1 then
         
            v_slot_status := 4;
         
         elsif nvl(p_extra_slot,0) = 1 then 
            
            v_slot_status := 2;
         
         else
            
            v_slot_status := 0;
               
         end if;
            
         insert into opd_appointment_slot
                     (slot_no, doctor_no, slot_date, start_time, end_time,
                      duration_min, extra_slot, slot_sl, shiftdtl_no, slot_status, slot_status_org,
                      ss_creator, ss_created_on, ss_created_session, company_no
                     )
              values (v_pk, p_doc_no, trunc (p_app_date), p_start_time, k_general.fd_add_daytime (p_start_time, 0, 0, p_duration, 0),
                      p_duration, p_extra_slot, nvl (v_slot_sl, 1), p_shift_no, 
                      v_slot_status, v_slot_status,
                      p_ss_creator, sysdate, p_ss_created_session, p_company_no
                     );

         p_slot_no := v_pk;
         
         commit;

      end if;
      
   exception when others then
         rollback;
   end pd_ins_app_slot;

procedure pd_ins_appointment (
      p_doctor_no              in number,
      p_appoint_date           in date,
      p_shiftdtl_no            in number,
      p_reg_no                 in number,
      p_patient_type           in number,
      p_salutation             in varchar2,
      p_patient_name           in varchar2,
      p_phone_mobile           in varchar2,
      p_email                  in varchar2,
      p_dob                    in date,
      p_age_dd                 in number,
      p_age_mm                 in number,
      p_age_yy                 in number,
      p_gender                 in varchar2,
      p_m_status               in varchar2,
      p_blood_group            in varchar2,
      p_address                in varchar2,
      p_consultation_type      in number,
      p_appoint_type           in varchar2,
      p_appoint_status         in number,
      p_app_from_flag          in number,
      p_chif_complain          in varchar2,    
      p_ss_creator             in  number,
      p_ss_created_session     in  number,
      p_ss_og_no               in  number,
      p_company_no             in  number,
      p_slot_no                in out number,
      p_slot_sl                in out number,
      p_start_time             in out date,
      p_end_time               in out date,
      p_appoint_no             out number,
      p_appoint_id             out varchar2,
      p_error                  out varchar2
      )

is

    cursor c_con_type_prfx
    is
    select consult_type_prifx
    from hpms_consulttype
    where consult_type_no = p_consultation_type;
    
    v_consult_type_prifx varchar2(10);
    
    cursor c_slot (p_slot number)
    is
    select slot_status
    from opd_appointment_slot
    where slot_no = p_slot
    for update of slot_status wait 60;
    r_c_slot    c_slot%rowtype;
    
    cursor c_auto_slot
    is
    select slot_no, slot_sl, start_time, end_time, slot_status
    from opd_appointment_slot
    where doctor_no = p_doctor_no
    and slot_date = p_appoint_date
    and shiftdtl_no = p_shiftdtl_no
    and end_time > sysdate
    and slot_sl = (select min(slot_sl)
                   from opd_appointment_slot
                   where doctor_no = p_doctor_no
                   and slot_date = p_appoint_date
                   and shiftdtl_no = p_shiftdtl_no
                   and slot_status in (0,6)
                   and end_time > sysdate)
    for update of slot_status wait 60;
    r_c_auto_slot    c_auto_slot%rowtype;
    
   ----------------------- 
    cursor c_doc_dept
    is
    select bu_no
    from hpms_doctor
    where doctor_no = p_doctor_no;
    
    v_c_doc_dept c_doc_dept%rowtype; 
   -----------------------  Cursor added by Md. Masud billah(26.04.2021) ,Consulted with ASM Imran.
                        --  Purpose : Insert doctor bu_no in opd_appointment table.
                        --  Requirement by Imran(JAVA).
                        --  Uses : Web Application.                     
    
            
begin
    
    if p_slot_sl is not null then
    
        open c_slot(p_slot_no);
        fetch c_slot into r_c_slot;
        
        if r_c_slot.slot_status not in (1,3,5) then
        
            k_general.pd_genarate_no ('SEQ_APPOINT_NO', p_company_no, p_appoint_no, 'YY', 10);
            
            open c_con_type_prfx;
            fetch c_con_type_prfx into v_consult_type_prifx;
            close c_con_type_prfx;
            
            open c_doc_dept; fetch c_doc_dept into v_c_doc_dept;  close c_doc_dept;
            
            
            k_general.pd_genarate_id (v_consult_type_prifx, 'OPD_APPOINTMENT', 'APPOINT_ID', p_company_no, p_appoint_id);
            
            insert into opd_appointment (appoint_no, appoint_id, appoint_date, doctor_no, 
                                         shiftdtl_no, consultation_type, slot_sl, slot_no, 
                                         start_time, end_time, reg_no, salutation, 
                                         patient_name, pat_type_no, phone_mobile, email, dob, 
                                         age_dd, age_mm, age_yy, gender, 
                                         m_status, address, blood_group, appoint_type, 
                                         appoint_status, chif_complain, ss_creator, ss_created_on, 
                                         ss_created_session, company_no, app_from_flag,bu_no)
            values (p_appoint_no, p_appoint_id, p_appoint_date, p_doctor_no, 
                    p_shiftdtl_no, p_consultation_type, p_slot_sl, p_slot_no, 
                    p_start_time, p_end_time, p_reg_no, p_salutation, 
                    p_patient_name, p_patient_type, p_phone_mobile, p_email, p_dob, 
                    p_age_dd, p_age_mm, p_age_yy, p_gender, 
                    p_m_status, p_address, p_blood_group, p_appoint_type, 
                    1, p_chif_complain, p_ss_creator, sysdate, 
                    p_ss_created_session, p_company_no, p_app_from_flag,v_c_doc_dept.bu_no); -- added doctor bu_no.                           
            
            update opd_appointment_slot
            set slot_status = p_appoint_status
            where slot_no = p_slot_no;
            
            commit;
            close c_slot;
            
        else
            
            p_error := 'Others user already booked this slot. Please check.';
            close c_slot;
            return;    
        
        end if;
    
    else
        
        open c_auto_slot;
        fetch c_auto_slot into r_c_auto_slot;
        
        if c_auto_slot%found then
            
            k_general.pd_genarate_no ('SEQ_APPOINT_NO', p_company_no, p_appoint_no, 'YY', 10);
            
            open c_con_type_prfx;
            fetch c_con_type_prfx into v_consult_type_prifx;
            close c_con_type_prfx;
            
            open c_doc_dept; fetch c_doc_dept into v_c_doc_dept;  close c_doc_dept;
            
            k_general.pd_genarate_id (v_consult_type_prifx, 'OPD_APPOINTMENT', 'APPOINT_ID', p_company_no, p_appoint_id);
            
            insert into opd_appointment (appoint_no, appoint_id, appoint_date, doctor_no, 
                                         shiftdtl_no, consultation_type, slot_sl, slot_no, 
                                         start_time, end_time, reg_no, salutation, 
                                         patient_name, phone_mobile, email, dob, 
                                         age_dd, age_mm, age_yy, gender, 
                                         m_status, address, blood_group, appoint_type, 
                                         appoint_status, chif_complain, ss_creator, ss_created_on, 
                                         ss_created_session, company_no, app_from_flag,bu_no)
            values (p_appoint_no, p_appoint_id, p_appoint_date, p_doctor_no, 
                    p_shiftdtl_no, p_consultation_type, r_c_auto_slot.slot_sl, r_c_auto_slot.slot_no, 
                    r_c_auto_slot.start_time, r_c_auto_slot.end_time, p_reg_no, p_salutation, 
                    p_patient_name, p_phone_mobile, p_email, p_dob, 
                    p_age_dd, p_age_mm, p_age_yy, p_gender, 
                    p_m_status, p_address, p_blood_group, p_appoint_type, 
                    1, p_chif_complain, p_ss_creator, sysdate, 
                    p_ss_created_session, p_company_no, p_app_from_flag,v_c_doc_dept.bu_no); -- added doctor bu_no.                           
            
            update opd_appointment_slot
            set slot_status = p_appoint_status
            where slot_no = r_c_auto_slot.slot_no;
            
            commit;
            close c_auto_slot;
            
            p_slot_no     := r_c_auto_slot.slot_no;
            p_slot_sl     := r_c_auto_slot.slot_sl;
            p_start_time  := r_c_auto_slot.start_time;
            p_end_time    := r_c_auto_slot.end_time;
      
        else
            
            p_error := 'All general slot of this doctor for this shift is booked. Please check.';
            close c_auto_slot;
            return;         
            
        end if;
        
    end if;
                                            
exception when others then 
    p_error := sqlerrm;
end pd_ins_appointment;



procedure pd_ins_appointment_98 (
      p_doctor_no              in number,
      p_outsource_no           in number,
      p_appoint_date           in date,
      p_shiftdtl_no            in number,
      p_reg_no                 in number,
      p_patient_type           in number,
      p_salutation             in varchar2,
      p_patient_name           in varchar2,
      p_phone_mobile           in varchar2,
      p_email                  in varchar2,
      p_dob                    in date,
      p_age_dd                 in number,
      p_age_mm                 in number,
      p_age_yy                 in number,
      p_gender                 in varchar2,
      p_m_status               in varchar2,
      p_blood_group            in varchar2,
      p_address                in varchar2,
      p_consultation_type      in number,
      p_appoint_type           in varchar2,
      p_appoint_status         in number,
      p_app_from_flag          in number,
      p_chif_complain          in varchar2,    
      p_ss_creator             in  number,
      p_ss_created_session     in  number,
      p_ss_og_no               in  number,
      p_company_no             in  number,
      p_slot_no                in out number,
      p_slot_sl                in out number,
      p_start_time             in out date,
      p_end_time               in out date,
      p_appoint_no             out number,
      p_appoint_id             out varchar2,
      p_error                  out varchar2
      )

is

    cursor c_con_type_prfx
    is
    select consult_type_prifx
    from hpms_consulttype
    where consult_type_no = p_consultation_type;
    
    v_consult_type_prifx varchar2(10);
    
    cursor c_slot (p_slot number)
    is
    select slot_status
    from opd_appointment_slot
    where slot_no = p_slot
    for update of slot_status wait 60;
    r_c_slot    c_slot%rowtype;
    
    cursor c_auto_slot
    is
    select slot_no, slot_sl, start_time, end_time, slot_status
    from opd_appointment_slot
    where doctor_no = p_doctor_no
    and slot_date = p_appoint_date
    and shiftdtl_no = p_shiftdtl_no
    and end_time > sysdate
    and slot_sl = (select min(slot_sl)
                   from opd_appointment_slot
                   where doctor_no = p_doctor_no
                   and slot_date = p_appoint_date
                   and shiftdtl_no = p_shiftdtl_no
                   and slot_status in (0,6)
                   and end_time > sysdate)
    for update of slot_status wait 60;
    r_c_auto_slot    c_auto_slot%rowtype;
            
begin
    
    if p_slot_sl is not null then
    
        open c_slot(p_slot_no);
        fetch c_slot into r_c_slot;
        
        if r_c_slot.slot_status not in (1,3,5) then
        
            k_general.pd_genarate_no ('SEQ_APPOINT_NO', p_company_no, p_appoint_no, 'YY', 10);
            
            open c_con_type_prfx;
            fetch c_con_type_prfx into v_consult_type_prifx;
            close c_con_type_prfx;
            
            k_general.pd_genarate_id (v_consult_type_prifx, 'OPD_APPOINTMENT', 'APPOINT_ID', p_company_no, p_appoint_id);
            
            insert into opd_appointment (appoint_no, appoint_id, appoint_date, doctor_no,outsource_no ,
                                         shiftdtl_no, consultation_type, slot_sl, slot_no, 
                                         start_time, end_time, reg_no, salutation, 
                                         patient_name, phone_mobile, email, dob, 
                                         age_dd, age_mm, age_yy, gender, 
                                         m_status, address, blood_group, appoint_type, 
                                         appoint_status, chif_complain, ss_creator, ss_created_on, 
                                         ss_created_session, company_no, app_from_flag)
            values (p_appoint_no, p_appoint_id, p_appoint_date, p_doctor_no,p_outsource_no ,
                    p_shiftdtl_no, p_consultation_type, p_slot_sl, p_slot_no, 
                    p_start_time, p_end_time, p_reg_no, p_salutation, 
                    p_patient_name, p_phone_mobile, p_email, p_dob, 
                    p_age_dd, p_age_mm, p_age_yy, p_gender, 
                    p_m_status, p_address, p_blood_group, p_appoint_type, 
                    1, p_chif_complain, p_ss_creator, sysdate, 
                    p_ss_created_session, p_company_no, p_app_from_flag);                           
            
            update opd_appointment_slot
            set slot_status = p_appoint_status
            where slot_no = p_slot_no;
            
            commit;
            close c_slot;
            
        else
            
            p_error := 'Others user already booked this slot. Please check.';
            close c_slot;
            return;    
        
        end if;
    
    else
        
        open c_auto_slot;
        fetch c_auto_slot into r_c_auto_slot;
        
        if c_auto_slot%found then
            
            k_general.pd_genarate_no ('SEQ_APPOINT_NO', p_company_no, p_appoint_no, 'YY', 10);
            
            open c_con_type_prfx;
            fetch c_con_type_prfx into v_consult_type_prifx;
            close c_con_type_prfx;
            
            k_general.pd_genarate_id (v_consult_type_prifx, 'OPD_APPOINTMENT', 'APPOINT_ID', p_company_no, p_appoint_id);
            
            insert into opd_appointment (appoint_no, appoint_id, appoint_date, doctor_no, 
                                         shiftdtl_no, consultation_type, slot_sl, slot_no, 
                                         start_time, end_time, reg_no, salutation, 
                                         patient_name, phone_mobile, email, dob, 
                                         age_dd, age_mm, age_yy, gender, 
                                         m_status, address, blood_group, appoint_type, 
                                         appoint_status, chif_complain, ss_creator, ss_created_on, 
                                         ss_created_session, company_no, app_from_flag)
            values (p_appoint_no, p_appoint_id, p_appoint_date, p_doctor_no, 
                    p_shiftdtl_no, p_consultation_type, r_c_auto_slot.slot_sl, r_c_auto_slot.slot_no, 
                    r_c_auto_slot.start_time, r_c_auto_slot.end_time, p_reg_no, p_salutation, 
                    p_patient_name, p_phone_mobile, p_email, p_dob, 
                    p_age_dd, p_age_mm, p_age_yy, p_gender, 
                    p_m_status, p_address, p_blood_group, p_appoint_type, 
                    1, p_chif_complain, p_ss_creator, sysdate, 
                    p_ss_created_session, p_company_no, p_app_from_flag);                           
            
            update opd_appointment_slot
            set slot_status = p_appoint_status
            where slot_no = r_c_auto_slot.slot_no;
            
            commit;
            close c_auto_slot;
            
            p_slot_no     := r_c_auto_slot.slot_no;
            p_slot_sl     := r_c_auto_slot.slot_sl;
            p_start_time  := r_c_auto_slot.start_time;
            p_end_time    := r_c_auto_slot.end_time;
      
        else
            
            p_error := 'All general slot of this doctor for this shift is booked. Please check.';
            close c_auto_slot;
            return;         
            
        end if;
        
    end if;
                                            
exception when others then 
    p_error := sqlerrm;
end pd_ins_appointment_98;

procedure pd_split_slot(
                      p_base_slot_no           in number,
                      p_ss_creator             in number,
                      p_ss_created_session     in number,
                      p_ss_og_no               in number,
                      p_company_no             in number,
                      p_error                  out varchar2
                      )
   as
      v_time_diff      number;
      v_avg_slot_dur   number;           
      v_remain_time    number;
      v_slot_dur       number;
      v_start_min      number;
      v_slot_no1       number;
        
      cursor cur_old_slot
      is
         select slot_no, doctor_no, slot_date, shiftdtl_no, 
                slot_sl, start_time, end_time, duration_min, extra_slot, slot_splited, slot_status, slot_status_org
           from opd_appointment_slot
          where slot_no = p_base_slot_no;

      rec_old_slot     cur_old_slot%rowtype;
   begin
     
      if p_base_slot_no is null
      then
         return;
      end if;

      open cur_old_slot;

      fetch cur_old_slot
       into rec_old_slot;

      close cur_old_slot;

      v_time_diff := rec_old_slot.duration_min;
      v_avg_slot_dur := floor (v_time_diff / 2);
      v_remain_time := mod (v_time_diff, 2);

      update opd_appointment_slot
         set slot_splited = 1,
             duration_min = v_avg_slot_dur,
             end_time = k_general.fd_add_daytime (start_time, 0, 0, v_avg_slot_dur, 0)
       where slot_no = rec_old_slot.slot_no;

      commit;

      for i in 2 .. 2
      loop
         if i = 2
         then      
            v_slot_dur := v_avg_slot_dur - 1 + v_remain_time;
         else
            v_slot_dur := v_avg_slot_dur;
         end if;

         if i - 1 > 0
         then         
            v_start_min := (v_avg_slot_dur * (i - 1)) + 1;
         else
            v_start_min := 0;
         end if;

         pd_ins_app_slot (p_doc_no               => rec_old_slot.doctor_no,
                          p_app_date             => rec_old_slot.slot_date,
                          p_shift_no             => rec_old_slot.shiftdtl_no,
                          p_start_time           => k_general.fd_add_daytime (rec_old_slot.start_time, 0, 0, v_start_min, 0),
                          p_end_time             => k_general.fd_add_daytime (rec_old_slot.start_time, 0, 0, v_start_min, 0),
                          p_duration             => v_slot_dur,
                          p_extra_slot           => 1,
                          p_slot_sl              => rec_old_slot.slot_sl,
                          p_ss_creator           => p_ss_creator,
                          p_og_no                => p_ss_og_no,
                          p_company_no           => p_company_no,
                          p_ss_created_session   => p_ss_created_session,
                          p_slot_no              => v_slot_no1,
                          p_error                => p_error
                          );
                             
      end loop;
      
   exception when others then
         rollback;
   end pd_split_slot;

procedure pd_app_delete (
                      p_appoint_no            in number,
                      p_cancel_reason         in varchar2,
                      p_ss_creator            in number,
                      p_ss_created_session    in number,
                      p_ss_og_no              in number,
                      p_company_no            in number,
                      p_error                 out varchar2
                     )
   as
      cursor cur_slot
      is
         select slot_no
           from opd_appointment a
          where appoint_no = p_appoint_no;

      rec_slot   cur_slot%rowtype;
   begin
      if p_appoint_no is not null
         and p_cancel_reason is not null
      then
         open cur_slot;

         fetch cur_slot
          into rec_slot;

         close cur_slot;

         if rec_slot.slot_no is not null
         then
            update opd_appointment
               set appoint_status = 0,
                   reg_no             = null,
                   salutation         = null,
                   patient_name      = null,
                   phone_mobile     = null,
                   age_dd            = null, 
                   age_mm            = null, 
                   age_yy            = null, 
                   dob              = null,
                   gender            = null, 
                   m_status            = null, 
                   address            = null, 
                   chif_complain    = null,
                   cancel_reason = p_cancel_reason,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where appoint_no = p_appoint_no;

            update opd_appointment_slot
               set slot_status = 6,
                   slot_status_org = 6,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where slot_no = rec_slot.slot_no;

            commit;
         else
            p_error := 'APPOINTMENT SLOT NOT FOUND.';
         end if;
      else
         p_error := 'SOME REQUIRED INFORMATION NOT FOUND.';
      end if;
   exception
      when others
      then
         p_error := sqlerrm;
   end pd_app_delete;

procedure pd_doctor_serial_reset(p_doctor_no in number, 
                                 p_app_date in date, 
                                 p_shift_no in number, 
                                 p_val out number)
is

cursor c_app 
is
select nvl(max(s.slot_sl),0) 
from opd_appointment o, opd_appointment_slot s
where o.slot_no = s.slot_no
and s.doctor_no = p_doctor_no
and s.slot_date = p_app_date
and o.shiftdtl_no = p_shift_no;

v_slot_sl number;

cursor c_sch
is
select nvl(sl,0) sl
from hpms_doc_app_sl
where doctor_no = p_doctor_no
and app_date    = p_app_date
and shiftdtl_no = p_shift_no
for update of sl wait 60;
v_sl number;

v_error varchar2(1000);

begin
    
    open c_sch;
    fetch c_sch into v_sl;
    
    if c_sch%notfound then
        
        open c_app; 
        fetch c_app into v_slot_sl;
        
        if c_app%notfound or v_slot_sl = 0 then
            
            insert into hpms_doc_app_sl(doctor_no, app_date, shiftdtl_no, sl)
            values (p_doctor_no, p_app_date, p_shift_no, 1);
            p_val := 1;
            commit;
        
        else

            insert into hpms_doc_app_sl(doctor_no, app_date, shiftdtl_no, sl)
            values (p_doctor_no,p_app_date, p_shift_no, v_slot_sl + 1);
            p_val := v_slot_sl + 1;
            commit;    
        end if;
        
        close c_app;
        
    else
    
        
        update hpms_doc_app_sl
        set sl = v_sl + 1
        where doctor_no = p_doctor_no
        and app_date    = p_app_date
        and shiftdtl_no = p_shift_no;
        p_val := v_sl + 1;
        commit;   
        
    end if;
    
    close c_sch;
    
exception when others then 
    rollback;
end pd_doctor_serial_reset; 

procedure pd_cosnultation_bill (
                              p_doctor_no              in number,
                              p_duration               in number,
                              p_appoint_no             in out number,
                              p_appoint_date           in date,
                              p_shiftdtl_no            in number,
                              p_reg_no                 in number,
                              p_hospital_number        in varchar2 default null,
                              p_patient_type_no        in number,
                              p_ref_doc_no             in number default null,
                              p_salutation             in varchar2,
                              p_patient_name           in varchar2,
                              p_phone_mobile           in varchar2,
                              p_email                  in varchar2,
                              p_dob                    in date,
                              p_age_dd                 in number,
                              p_age_mm                 in number,
                              p_age_yy                 in number,
                              p_gender                 in varchar2,
                              p_m_status               in varchar2,
                              p_blood_group            in varchar2,
                              p_address                in varchar2,
                              p_bu_no                  in number,
                              p_consultation_type_no   in number,
                              p_appoint_type           in varchar2,
                              p_appoint_status         in number,
                              p_app_from_flag          in number,
                              p_chif_complain          in varchar2,    
                              p_consult_fee            in number,
                              p_next_followup_date     in date,
                              p_pres_admission_date    in date,
                              p_cor_client_no          in number default null,
                              p_cor_client_emp_id      in varchar2 default null,
                              p_emp_no                 in number default null,
                              p_relation_no            in number default null,
                              p_remarks                in varchar2 default null,
                              p_salesrep_no            in number default null,
                              p_card_no                in number default null,
                              p_item_no                in k_opd.arlist_numb,
                              p_item_name              in k_opd.arlist_varc,
                              p_item_qty               in k_opd.arlist_numb,
                              p_itemtype_no            in k_opd.arlist_numb,
                              p_par_itemtype_no        in k_opd.arlist_numb,
                              p_item_rate              in k_opd.arlist_numb,
                              p_item_vat               in k_opd.arlist_numb,
                              p_urgent_fee             in k_opd.arlist_numb,
                              p_service_charge         in k_opd.arlist_numb,
                              p_delivery_status_no     in k_opd.arlist_numb,
                              p_package_item_flag      in k_opd.arlist_numb,
                              p_cli_disc_amt           in k_opd.arlist_numb,
                              p_item_index             in number,
                              p_pay_mode               in k_opd.arlist_numb,
                              p_coll_mode              in k_opd.arlist_numb,
                              p_pay_type_no            in k_opd.arlist_numb,
                              p_pay_cqcc_others        in k_opd.arlist_varc,
                              p_pay_bank_name          in k_opd.arlist_varc,
                              p_pay_amt                in k_opd.arlist_numb,
                              p_given_amt              in k_opd.arlist_numb,
                              p_pay_index              in number   default 0,
                              p_disc_amount            in number   default null,
                              p_disctype_no            in number   default null,  
                              p_disc_auth_by           in number   default null,
                              p_disc_remarks           in varchar2 default null,
                              p_ss_creator             in number,
                              p_ss_created_session     in number,
                              p_og_no                  in number,
                              p_company_no             in number,
                              p_slot_no                in out number,
                              p_slot_sl                in out number,
                              p_start_time             in out date,
                              p_end_time               in out date,
                              p_consultation_no        out number,
                              p_consultation_id        out varchar2,
                              p_invoice_no             out number,
                              p_invoice_id             out varchar2,
                              p_error                  out varchar2
                              )

is
    
    cursor c_app
    is
    select max(slot_no) slot_no, max(start_time) start_time, max(end_time) end_time
    from opd_appointment
    where doctor_no  = nvl(p_doctor_no, 26)
    and appoint_date = p_appoint_date
    and shiftdtl_no  = p_shiftdtl_no;
    
    r_c_app    c_app%rowtype;
    
    cursor c_app_chk    -- To check consultation already done or not against this appointment no.
    is
    select appointment_no
    from opd_consultation
    where appointment_no  = p_appoint_no;
    
    r_c_app_chk    c_app_chk%rowtype;
        
    cursor c_con_type_prfx
    is
    select consult_type_prifx
    from hpms_consulttype
    where consult_type_no = p_consultation_type_no;
    
    v_appoint_id varchar2(50);
    v_consult_type_prifx varchar2(10);
    
    cursor c_item
    is
    select item_no, item_id, item_name, itemtype_no, bu_no, sales_price, vat
    from in_item
    where itemtype_no = 14
    and bu_no = p_bu_no
    and nvl(active_stat,0) = 0;
    
    r_c_item c_item%rowtype;
    
    cursor c_config
    is
    select hn_prifix, opd_invoice_prifix, invoince_method
    from opd_config
    where company_no = p_company_no;
    r_c_config  c_config%rowtype;
    
    v_hospital_number varchar2(50);
    v_reg_no number;
    v_invoice_no number;
    v_invoice_id varchar2(50);
    
    i_item_no                   k_opd.arlist_numb;
    i_item_name                 k_opd.arlist_varc;
    i_item_qty                  k_opd.arlist_numb;
    i_item_rate                 k_opd.arlist_numb;
    i_item_vat                  k_opd.arlist_numb;
    i_urgent_fee                k_opd.arlist_numb;
    i_service_charge            k_opd.arlist_numb;
    i_itemtype_no               k_opd.arlist_numb;
    i_par_itemtype_no           k_opd.arlist_numb;
    i_bu_no                     k_opd.arlist_numb;
    i_delivery_status_no        k_opd.arlist_numb;
    i_package_item_flag         k_opd.arlist_numb;
    i_cli_disc_amt              k_opd.arlist_numb;
    
    j_pay_mode                  k_opd.arlist_numb;
    j_coll_mode                 k_opd.arlist_numb;
    j_pay_type_no               k_opd.arlist_numb;
    j_pay_cqcc_others           k_opd.arlist_varc;
    j_pay_bank_name             k_opd.arlist_varc;
    j_pay_amt                   k_opd.arlist_numb;
    j_given_amt                 k_opd.arlist_numb;
                                        
begin
   
    open c_config;
    fetch c_config into r_c_config;
    close c_config;
    
    if p_slot_no is null then
    
        pd_doctor_serial_reset(p_doctor_no, p_appoint_date, p_shiftdtl_no, p_slot_sl);
        
        open c_app;
        
        fetch c_app into r_c_app;
        
        if c_app%found then
            
            close c_app;
            
            p_start_time := r_c_app.end_time;
            
            p_end_time   := r_c_app.end_time +.00001*69.445 * nvl(p_duration,1);
            
        else
        
            close c_app; 
            
            p_start_time := sysdate;
            
            p_end_time   := sysdate +.00001*69.445 * nvl(p_duration,1);
                       
        end if;
                    
        k_general.pd_genarate_no ('SEQ_SLOT_NO', p_company_no, p_slot_no);
        
        if p_slot_no is null then
        
         p_error := 'CANNOT GENERATE THE PRIMARY KEY SLOT NO';
        else
                            
        insert into opd_appointment_slot (slot_no, doctor_no, slot_date, shiftdtl_no, start_time, end_time,
                                          duration_min, extra_slot, slot_sl, slot_status,
                                          ss_creator, ss_created_on, ss_created_session, company_no)
        values (p_slot_no, p_doctor_no, p_appoint_date, P_shiftdtl_no, p_start_time, p_end_time,
                nvl(p_duration,1), 0, p_slot_sl, 1,
                p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        end if;
    
    end if;
    
    if p_reg_no is null then
        
        k_general.pd_genarate_id (r_c_config.hn_prifix, 'OPD_REGISTRATION', 'HOSPITAL_NUMBER', p_company_no, v_hospital_number);
        k_general.pd_genarate_no ('SEQ_REG_NO', p_company_no, v_reg_no, 'YY', 10);
        
        if v_reg_no is null or v_hospital_number is null then
        
         p_error := 'CANNOT GENERATE THE PRIMARY KEY REG NO';
        
        else
        
        insert into opd_registration (reg_no, hospital_number, reg_date, salutation, 
                                      fname, lname, gender, m_status, 
                                      age_dd, age_mm, age_yy, dob, 
                                      blood_group, religion, phone_mobile, email, 
                                      address, national_id, pat_type_no, reg_point, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
                                      
        values (v_reg_no, v_hospital_number, sysdate, p_salutation, 
                p_patient_name, null, p_gender, p_m_status, 
                p_age_dd, p_age_mm, p_age_yy, p_dob, 
                p_blood_group, null, p_phone_mobile, p_email, 
                p_address, null, p_patient_type_no, 1, p_ss_creator, 
                sysdate, p_ss_created_session, p_company_no);
       end if;
       
        
    else
        /*
        update opd_registration
        set  age_dd = p_age_dd, 
             age_mm = p_age_mm, 
             age_yy = p_age_yy, 
             dob    = p_dob
        where reg_no = p_reg_no;
        */
        v_reg_no := p_reg_no;
        v_hospital_number := p_hospital_number;
        
    end if;

    if p_appoint_no is null then
    
        open c_con_type_prfx;
        fetch c_con_type_prfx into v_consult_type_prifx;
        close c_con_type_prfx;
        
        k_general.pd_genarate_no ('SEQ_APPOINT_NO', p_company_no, p_appoint_no, 'YY', 10);            
        k_general.pd_genarate_id (v_consult_type_prifx, 'OPD_APPOINTMENT', 'APPOINT_ID', p_company_no, v_appoint_id);
        
       if p_appoint_no is null or v_appoint_id is null then 
        
        p_error := 'CANNOT GENERATE THE PRIMARY KEY APPOINTMENT NO';
        else    
        insert into opd_appointment (appoint_no, appoint_id, appoint_date, doctor_no, 
                                     shiftdtl_no, consultation_type, slot_sl, slot_no, 
                                     start_time, end_time, reg_no, salutation, 
                                     patient_name, phone_mobile, email, dob, 
                                     age_dd, age_mm, age_yy, gender, pat_type_no,bu_no, 
                                     m_status, address, blood_group, appoint_type, 
                                     appoint_status, chif_complain, ss_creator, ss_created_on, 
                                     ss_created_session, company_no, app_from_flag)
        values (p_appoint_no, v_appoint_id, p_appoint_date, p_doctor_no, 
                p_shiftdtl_no, p_consultation_type_no, p_slot_sl, p_slot_no, 
                p_start_time, p_end_time, v_reg_no, p_salutation, 
                p_patient_name, p_phone_mobile, p_email, p_dob, 
                p_age_dd, p_age_mm, p_age_yy, p_gender,p_patient_type_no, p_bu_no, 
                p_m_status, p_address, p_blood_group, p_appoint_type, 
                1, p_chif_complain, p_ss_creator, sysdate, 
                p_ss_created_session, p_company_no, p_app_from_flag);                           
            
       end  if;

        k_general.pd_genarate_no ('SEQ_OPD_CONSULTATION_NO', p_company_no, p_consultation_no, 'YY', 10);
        k_general.pd_genarate_id ('C', 'OPD_CONSULTATION', 'OPD_CONSULTATION_ID', p_company_no, p_consultation_id);
        
        if p_consultation_no is null or p_consultation_id is null then 
        
        p_error := 'CANNOT GENERATE THE PRIMARY KEY CONSULTATION NO';
        else
        
        insert into opd_consultation (opd_consultation_no, opd_consultation_id, doctor_no, consult_type_no,
                                      consultation_date, consultation_datetime, reg_no, appointment_no,
                                      consult_fee, ref_doctor_no, consult_reason, next_followup_date, bu_no,
                                      prescribed_admission_date, ss_creator, ss_created_on, ss_created_session,
                                      company_no, salesrep_no)
        values (p_consultation_no, p_consultation_id, p_doctor_no, p_consultation_type_no,
               trunc(sysdate), sysdate, v_reg_no, p_appoint_no,
               p_consult_fee, p_ref_doc_no, p_chif_complain, p_next_followup_date, p_bu_no,
               p_pres_admission_date, p_ss_creator, sysdate, p_ss_created_session,
               p_company_no, p_salesrep_no);
        end if;
        
    else
        -- To check consultation already done or not against this appointment no.
        open c_app_chk;
        fetch c_app_chk into r_c_app_chk;
        close c_app_chk;
        
        if r_c_app_chk.appointment_no is not null then
            p_error := 'Already consultation done for this appointment. Please refresh the screen and check again.';
            goto end_level;
        end if;
        --End To check consultation already done or not against this appointment no.
        
        update opd_appointment
        set reg_no = nvl(v_reg_no, p_reg_no)
        where appoint_no = p_appoint_no;
        
        k_general.pd_genarate_no ('SEQ_OPD_CONSULTATION_NO', p_company_no, p_consultation_no, 'YY', 10);
        k_general.pd_genarate_id ('C', 'OPD_CONSULTATION', 'OPD_CONSULTATION_ID', p_company_no, p_consultation_id);
        
        if p_consultation_no is null or p_consultation_id is null then 
        
        p_error := 'CANNOT GENERATE THE PRIMARY KEY CONSULTATION NO';
        else
        
        insert into opd_consultation (opd_consultation_no, opd_consultation_id, doctor_no, consult_type_no,
                                      consultation_date, consultation_datetime, reg_no, appointment_no,
                                      consult_fee, ref_doctor_no, consult_reason, next_followup_date, bu_no,
                                      prescribed_admission_date, ss_creator, ss_created_on, ss_created_session,
                                      company_no, salesrep_no)
        values (p_consultation_no, p_consultation_id, p_doctor_no, p_consultation_type_no,
               trunc(sysdate), sysdate, v_reg_no, p_appoint_no,
               p_consult_fee, p_ref_doc_no, p_chif_complain, p_next_followup_date, p_bu_no,
               p_pres_admission_date, p_ss_creator, sysdate, p_ss_created_session,
               p_company_no, p_salesrep_no);
        end if;
        
    end if;
    
    --if nvl(p_consult_fee,0) > 0 then
        
        for i in 1..p_item_index loop
            
            i_item_no                   (i) := p_item_no (i);
            i_item_name                 (i) := p_item_name (i);
            i_item_qty                  (i) := p_item_qty (i);
            i_item_rate                 (i) := p_item_rate (i);
            i_item_vat                  (i) := p_item_vat (i);
            i_urgent_fee                (i) := p_urgent_fee (i);
            i_service_charge            (i) := p_service_charge (i);
            i_itemtype_no               (i) := p_itemtype_no (i);
            i_par_itemtype_no           (i) := p_par_itemtype_no (i);
            i_bu_no                     (i) := p_bu_no;
            i_delivery_status_no        (i) := p_delivery_status_no (i);
            i_package_item_flag         (i) := p_package_item_flag (i);
            i_cli_disc_amt              (i) := p_cli_disc_amt (i);
              
        end loop;    
        
        for j in 1..p_pay_index loop
            
            j_pay_mode                  (j) := p_pay_mode (j);
            j_coll_mode                 (j) := p_coll_mode (j);
            j_pay_type_no               (j) := p_pay_type_no (j);
            j_pay_cqcc_others           (j) := p_pay_cqcc_others (j);
            j_pay_bank_name             (j) := p_pay_bank_name (j);
            j_pay_amt                   (j) := p_pay_amt (j);
            j_given_amt                 (j) := p_given_amt (j);
              
        end loop;
        
        
      if p_consultation_no is not null --and  nvl(p_consult_fee,0) > 0 
      then
        
        pd_invoice ( p_reg_no                    => v_reg_no,
                     p_hospital_number           => v_hospital_number,
                     p_pat_type_no               => p_patient_type_no,
                     p_admission_no              => null,
                     p_admission_id              => null,
                     p_consultation_no           => p_consultation_no,
                     p_bed_no                    => null,
                     p_salutation                => p_salutation,
                     p_fname                     => p_patient_name,
                     p_lname                     => null,
                     p_gender                    => p_gender,
                     p_m_status                  => p_m_status,
                     p_age_dd                    => p_age_dd,
                     p_age_mm                    => p_age_mm,
                     p_age_yy                    => p_age_yy,
                     p_phone_mobile              => p_phone_mobile,
                     p_dob                       => p_dob,
                     p_address                   => p_address,
                     p_blood_group               => p_blood_group,
                     p_religion                  => null,
                     p_email                     => p_email,
                     p_national_id               => null,
                     p_ref_doc_no                => p_ref_doc_no,
                     p_remarks                   => p_remarks,
                     p_delivery_date             => null,
                     p_bill_module_no            => 9,
                     p_item_no                   => i_item_no,
                     p_item_name                 => i_item_name,
                     p_item_qty                  => i_item_qty,
                     p_item_rate                 => i_item_rate,
                     p_item_vat                  => i_item_vat,
                     p_urgent_fee                => i_urgent_fee,
                     p_service_charge            => i_service_charge,
                     p_itemtype_no               => i_itemtype_no,
                     p_par_itemtype_no           => i_par_itemtype_no,
                     p_bu_no                     => i_bu_no,
                     p_delivery_status_no        => i_delivery_status_no,
                     p_package_item_flag         => i_package_item_flag,
                     p_cli_disc_amt              => i_cli_disc_amt,
                     p_item_index                => p_item_index,
                     p_cor_client_no             => p_cor_client_no,
                     p_cor_client_emp_id         => p_cor_client_emp_id,
                     p_card_no                   => p_card_no,
                     p_emp_no                    => p_emp_no,
                     p_relation_no               => p_relation_no,
                     p_pay_mode                  => j_pay_mode,
                     p_coll_mode                 => j_coll_mode,
                     p_pay_type_no               => j_pay_type_no,
                     p_pay_cqcc_others           => j_pay_cqcc_others,
                     p_pay_bank_name             => j_pay_bank_name,
                     p_pay_amt                   => j_pay_amt,
                     p_given_amt                 => j_given_amt,
                     p_pay_index                 => p_pay_index,
                     p_disc_amount               => p_disc_amount,
                     p_disctype_no               => p_disctype_no,  
                     p_disc_auth_by              => p_disc_auth_by,
                     p_disc_remarks              => p_disc_remarks,
                     p_ss_creator                => p_ss_creator,
                     p_og_no                     => p_og_no,
                     p_company_no                => p_company_no,
                     p_ss_created_session        => p_ss_created_session,
                     p_invoice_no                => p_invoice_no,
                     p_invoice_id                => p_invoice_id,
                     p_error                     => p_error
                     );
      else 
      p_error := 'Bill cannot be generated.';
      end if;
      
    
    --end if;
    
    <<end_level>>
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
        
exception when others then 
    p_error := sqlerrm;
    rollback;
    
end pd_cosnultation_bill;

procedure pd_invoice (
                      p_reg_no                    in       number default null,
                      p_hospital_number           in       varchar2 default null,
                      p_pat_type_no               in       number default null,
                      p_admission_no              in       number default null,
                      p_admission_id              in       varchar2 default null,
                      p_consultation_no           in       number default null,
                      p_bed_no                    in       number default null,
                      p_salutation                in       varchar2,
                      p_fname                     in       varchar2,
                      p_lname                     in       varchar2,
                      p_gender                    in       varchar2,
                      p_m_status                  in       varchar2,
                      p_age_dd                    in       number,
                      p_age_mm                    in       number,
                      p_age_yy                    in       number,
                      p_phone_mobile              in       varchar2,
                      p_dob                       in       date default null,
                      p_address                   in       varchar2 default null,
                      p_blood_group               in       varchar2 default null,
                      p_religion                  in       varchar2 default null,
                      p_email                     in       varchar2 default null,
                      p_national_id               in       varchar2 default null,
                      p_ref_doc_no                in       number default null,
                      p_remarks                   in       varchar2 default null,
                      p_delivery_date             in       date default null,
                      p_bill_module_no            in       number,
                      p_item_no                   in       k_opd.arlist_numb,
                      p_item_name                 in       k_opd.arlist_varc,
                      p_item_qty                  in       k_opd.arlist_numb,
                      p_item_rate                 in       k_opd.arlist_numb,
                      p_item_vat                  in       k_opd.arlist_numb,
                      p_urgent_fee                in       k_opd.arlist_numb,
                      p_service_charge            in       k_opd.arlist_numb,
                      p_itemtype_no               in       k_opd.arlist_numb,
                      p_par_itemtype_no           in       k_opd.arlist_numb,
                      p_bu_no                     in       k_opd.arlist_numb,
                      p_delivery_status_no        in       k_opd.arlist_numb,
                      p_package_item_flag         in       k_opd.arlist_numb,
                      p_cli_disc_amt              in       k_opd.arlist_numb,
                      p_item_index                in       number,
                      p_cor_client_no             in       number default null,
                      p_cor_client_emp_id         in       varchar2 default null,
                      p_emp_no                    in       number default null,
                      p_relation_no               in       number default null,
                      p_card_no                   in       number default null,
                      p_pay_mode                  in       k_opd.arlist_numb,
                      p_coll_mode                 in       k_opd.arlist_numb,
                      p_pay_type_no               in       k_opd.arlist_numb,
                      p_pay_cqcc_others           in       k_opd.arlist_varc,
                      p_pay_bank_name             in       k_opd.arlist_varc,
                      p_pay_amt                   in       k_opd.arlist_numb,
                      p_given_amt                 in       k_opd.arlist_numb,
                      p_pay_index                 in       number   default 0,
                      p_disc_amount               in       number   default null,
                      p_disctype_no               in       number   default null,  
                      p_disc_auth_by              in       number   default null,
                      p_disc_remarks              in       varchar2 default null,
                      p_ss_creator                in       number,
                      p_og_no                     in       number,
                      p_company_no                in       number,
                      p_ss_created_session        in       number,
                      p_invoice_no                out      number,
                      p_invoice_id                out      varchar2,
                      p_error                     out      varchar2
                     )
as

    cursor c_config
    is
    select hn_prifix, opd_invoice_prifix, invoince_method
    from opd_config
    where company_no = p_company_no;
    r_c_config  c_config%rowtype;
    
    v_reg_no            number;
    v_hospital_number   varchar2(50);
    v_bill_index        number := 1;
    v_pay_index         number := 1;
    v_invoicedtl_no     number;
    v_lab_exist         number := 0;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    v_paydtl_no         number;
    
    i_invoicedtl_no         k_ledger.arlist_numb;
    i_item_no               k_ledger.arlist_numb;
    i_item_name             k_ledger.arlist_varc;
    i_item_qty              k_ledger.arlist_numb;
    i_item_rate             k_ledger.arlist_numb;
    i_item_vat              k_ledger.arlist_numb;
    i_urgent_fee            k_ledger.arlist_numb;
    i_service_charge        k_ledger.arlist_numb;
    i_itemtype_no           k_ledger.arlist_numb;
    i_par_itemtype_no       k_ledger.arlist_numb;
    i_bu_no                 k_ledger.arlist_numb;
    i_delivery_status_no    k_ledger.arlist_numb;
    i_package_item_flag     k_ledger.arlist_numb;
    i_pur_rate              k_ledger.arlist_numb;  
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
   
    v_opd_visit_no  number;----add md masud 09032020 for imperial hospital
    v_opd_visit_id  varchar2(30);
    
begin


    
    open c_config;
    fetch c_config into r_c_config;
    close c_config;
    
    if p_reg_no is null then
    
        k_general.pd_genarate_id (r_c_config.hn_prifix, 'OPD_REGISTRATION', 'HOSPITAL_NUMBER', p_company_no, v_hospital_number);
        k_general.pd_genarate_no ('SEQ_REG_NO', p_company_no, v_reg_no, 'YY', 10);
        
        insert into opd_registration (reg_no, hospital_number, reg_date, salutation, 
                                      fname, lname, gender, m_status, 
                                      age_dd, age_mm, age_yy, dob, 
                                      blood_group, religion, phone_mobile, email, 
                                      address, national_id, pat_type_no, reg_point, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
                                      
        values (v_reg_no, v_hospital_number, sysdate, p_salutation, 
                p_fname, p_lname, p_gender, p_m_status, 
                p_age_dd, p_age_mm, p_age_yy, p_dob, 
                p_blood_group, p_religion, p_phone_mobile, p_email, 
                p_address, p_national_id, p_pat_type_no, 5, p_ss_creator, 
                sysdate, p_ss_created_session, p_company_no);
    
    else
        v_reg_no := p_reg_no;        
    end if;
    
    if p_og_no in(5,117) then   ----add md masud 09032020 for imperial hospital
    
        pd_opd_patient_visit_insert (
                            p_reg_no                    => nvl(v_reg_no,p_reg_no),
                            p_admission_no              => p_admission_no, 
                            p_bill_module_no            => p_bill_module_no,
                            p_pat_type_no               => p_pat_type_no,                     
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_opd_visit_no              => v_opd_visit_no,
                            p_opd_visit_id              => v_opd_visit_id,
                            p_error                     => p_error
                            );
             if  p_error is not null then
              rollback;
              return;
             end if;
    end if;
       
    k_general.pd_genarate_no ('SEQ_INVOICE_NO', p_company_no, p_invoice_no,'YY', 10);
    
    if r_c_config.invoince_method is null then
        
        k_general.pd_genarate_id (r_c_config.opd_invoice_prifix, 'OPD_INVOICE', 'OPD_INVOICE_ID', p_company_no, p_invoice_id);
            
    else    
        
        execute immediate 'SELECT '||r_c_config.invoince_method|| ' FROM SYS.DUAL' into p_invoice_id;
            
    end if;
    
    insert into opd_invoice (opd_invoice_no, opd_invoice_id, bill_module_no, reg_no, 
                              admission_no, admission_id, consultation_no, invoice_date, 
                              invoice_datetime, doctor_no, remarks,bu_no, 
                              cor_client_no,  cor_client_card_no, emp_no, relation_no, 
                              pat_type_no, ss_creator, ss_created_on, 
                              ss_created_session, company_no, card_no,opd_visit_no)
    values (p_invoice_no, p_invoice_id, p_bill_module_no, v_reg_no,
            p_admission_no, p_admission_id, p_consultation_no, trunc(sysdate),
            sysdate, p_ref_doc_no, p_remarks,p_bu_no (1),
            p_cor_client_no, p_cor_client_emp_id, p_emp_no, p_relation_no, 
            p_pat_type_no, p_ss_creator, sysdate, 
            p_ss_created_session, p_company_no, p_card_no,v_opd_visit_no);
    
    loop
    
        k_general.pd_genarate_no ('SEQ_INVOICEDTL_NO', p_company_no, v_invoicedtl_no,'YY',10);
          
        insert into opd_invoicedtl(opd_invoicedtl_no, opd_invoice_no, item_no, item_name, 
                                    itemtype_no, item_qty, item_rate, item_vat, 
                                    urgent_fee, service_charge, package_item_flag, bu_no, 
                                    ss_creator, ss_created_on, ss_created_session, company_no)
        values(v_invoicedtl_no, p_invoice_no, p_item_no (v_bill_index), p_item_name (v_bill_index), 
               p_itemtype_no (v_bill_index), p_item_qty (v_bill_index), p_item_rate (v_bill_index), p_item_vat (v_bill_index), 
               p_urgent_fee (v_bill_index), p_service_charge (v_bill_index), p_package_item_flag (v_bill_index), p_bu_no (v_bill_index), 
               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        i_invoicedtl_no (v_bill_index) := v_invoicedtl_no;
        i_item_no            (v_bill_index) := p_item_no (v_bill_index);
        i_item_name          (v_bill_index) := p_item_name (v_bill_index);
        i_item_qty           (v_bill_index) := p_item_qty (v_bill_index);
        i_item_rate          (v_bill_index) := p_item_rate (v_bill_index);
        i_item_vat           (v_bill_index) := p_item_vat (v_bill_index);
        i_urgent_fee         (v_bill_index) := p_urgent_fee (v_bill_index);
        i_service_charge     (v_bill_index) := p_service_charge (v_bill_index);
        i_itemtype_no        (v_bill_index) := p_itemtype_no (v_bill_index);
        i_par_itemtype_no    (v_bill_index) := p_par_itemtype_no (v_bill_index);
        i_bu_no              (v_bill_index) := p_bu_no (v_bill_index);
        i_delivery_status_no (v_bill_index) := p_delivery_status_no (v_bill_index);
        i_package_item_flag  (v_bill_index) := p_package_item_flag (v_bill_index);
        i_pur_rate           (v_bill_index) := null;
                                           
    exit when v_bill_index >= nvl (p_item_index, 0);
        v_bill_index := v_bill_index + 1; 
    end loop;
    
                                  
    k_ledger.pd_ledger_bill(p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_ref_doc_no                => p_ref_doc_no,
                            p_second_ref_doc_no         => null, 
                            p_doctor_no                 => p_ref_doc_no,
                            p_invoicedtl_no             => i_invoicedtl_no,                    
                            p_item_no                   => i_item_no,
                            p_item_name                 => i_item_name,
                            p_item_qty                  => i_item_qty,
                            p_item_rate                 => i_item_rate,
                            p_item_vat                  => i_item_vat,
                            p_urgent_fee                => i_urgent_fee,
                            p_service_charge            => i_service_charge,
                            p_itemtype_no               => i_itemtype_no,
                            p_par_itemtype_no           => i_par_itemtype_no,
                            p_bu_no                     => i_bu_no,
                            p_delivery_status_no        => i_delivery_status_no,
                            p_package_item_flag         => i_package_item_flag,
                            p_pur_rate                  => i_pur_rate,
                            p_inv_index                 => v_bill_index,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
                      
    v_bill_index := 1;
    
    if nvl(p_disc_amount,0) > 0 then
        
        k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
        k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);            
  
        insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                  reg_no, invoice_no, admission_no, disc_type_no, pay_amt,
                                  pay_type_no, disc_auth_by, disc_remarks, ss_creator, 
                                  ss_created_on, ss_created_session, company_no)
        values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
               v_reg_no, p_invoice_no, p_admission_no, p_disctype_no, p_disc_amount,
               6, p_disc_auth_by, p_disc_remarks, p_ss_creator, 
               sysdate, p_ss_created_session, p_company_no);    
        
        loop
        
            k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY',10);    
        
            insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                         reg_no, invoice_no, invoicedtl_no, admission_no, 
                                         item_no, bill_module_no, disc_type_no, cli_disc_amt, 
                                         ss_creator, ss_created_on, ss_created_session, company_no)
            values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                   v_reg_no, p_invoice_no, i_invoicedtl_no (v_bill_index), p_admission_no,
                   p_item_no (v_bill_index), p_bill_module_no, p_disctype_no, p_cli_disc_amt (v_bill_index),
                   p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        exit when v_bill_index >= nvl (p_item_index, 0);
            v_bill_index := v_bill_index + 1; 
        end loop;
        
        i_pay_no        (1) := v_pay_no;
        i_pay_mode      (1) := null;
        i_coll_mode     (1) := null;
        i_pay_type_no   (1) := 6;
        i_amount        (1) := p_disc_amount;
        i_given_amt     (1) := null;
        
        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => 1,
                            p_disctype_no               => p_disctype_no,  
                            p_disc_auth_by              => p_disc_auth_by,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
        
    end if;
      
    if nvl(p_pay_index,0) > 0 then
    
        loop
        
            k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
            k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);
            
            insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                      reg_no, invoice_no, admission_no, pay_amt, 
                                      pay_type_no, pay_mode, coll_mode, pay_cqcc_others, 
                                      pay_bank_name, given_amt, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
            values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
                   v_reg_no, p_invoice_no, p_admission_no, p_pay_amt (v_pay_index), 
                   p_pay_type_no (v_pay_index), p_pay_mode (v_pay_index), p_coll_mode (v_pay_index), p_pay_cqcc_others (v_pay_index), 
                   p_pay_bank_name (v_pay_index), p_given_amt (v_pay_index), p_ss_creator, 
                   sysdate, p_ss_created_session, p_company_no);
        
            i_pay_no        (v_pay_index) := v_pay_no;
            i_pay_mode      (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode     (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no   (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount        (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt     (v_pay_index) := p_given_amt (v_pay_index);
                
        exit when v_pay_index >= nvl (p_pay_index, 0);
            v_pay_index := v_pay_index + 1; 
        end loop;

        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_pay_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
                    
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_invoice;

procedure pd_item_cancel(
                      p_invoice_no          in number,
                      p_invoice_id          in varchar2, 
                      p_reg_no              in number, 
                      p_admission_no        in number   default null, 
                      p_admission_id        in varchar2 default null,
                      p_bed_no              in number   default null, 
                      p_consultation_no     in number   default null,
                      p_bill_module_no      in number,
                      p_invoicedtl_no       in k_opd.arlist_numb,
                      p_item_no             in k_opd.arlist_numb,
                      p_item_qty            in k_opd.arlist_numb,
                      p_itemtype_no         in k_opd.arlist_numb,
                      p_cancel_reason       in k_opd.arlist_varc,
                      p_index               in number,
                      p_ss_creator          in number,
                      p_og_no               in number,
                      p_company_no          in number,
                      p_ss_created_session  in number,
                      p_error               out varchar2
                      )
is

    cursor c_cancel (p_invdtl_no number)
    is
      select item_no, item_name, item_qty, cancel_qty, cancel_flag,
             item_rate, nvl(item_vat,0) item_vat, 
             nvl(urgent_fee,0) urgent_fee, 
             nvl(service_charge,0) service_charge,
             item_qty - nvl(cancel_qty,0) act_qty
       from opd_invoicedtl
      where opd_invoicedtl_no = p_invdtl_no
        for update of cancel_flag, cancel_qty wait 60;

    r_c_cancel c_cancel%rowtype;  
    
    v_index number := 1;
    v_addcancel_no number;
    v_disc_index number := 0;
    
    i_pay_no        k_ledger.arlist_numb;
    i_pay_mode      k_ledger.arlist_numb;
    i_coll_mode     k_ledger.arlist_numb;
    i_pay_type_no   k_ledger.arlist_numb;
    i_amount        k_ledger.arlist_numb;
    i_given_amt     k_ledger.arlist_numb;
    
    v_item_total      number := 0;
    v_vat_total       number := 0; 
    v_urg_fee_total   number := 0; 
    v_ser_cha_total   number := 0;

    cursor c_disc (p_invoicedtl number, p_item number)
    is
    select count(1)
    from bill_paymentdtl
    where invoice_no = p_invoice_no
    and invoicedtl_no = p_invoicedtl
    and item_no = p_item;
    v_exist number;
    
    cursor c_disc_return (p_invoicedtl number, p_item number)
    is
    select sum(nvl(cli_disc_amt,0) - nvl(cli_disc_ref,0)) cli_disc, 
           sum(nvl(ref_disc_amt,0) - nvl(ref_disc_ref,0)) ref_disc
    from bill_paymentdtl
    where invoice_no = p_invoice_no
    and invoicedtl_no = p_invoicedtl
    and item_no = p_item
    having sum(nvl(cli_disc_amt,0) - nvl(cli_disc_ref,0)) > 0
        or sum(nvl(ref_disc_amt,0) - nvl(ref_disc_ref,0)) > 0;

    i_invoicedtl_no  k_opd.arlist_numb;
    i_item_no        k_opd.arlist_numb;
    i_item_qty       k_opd.arlist_numb;
    
    v_error          varchar2(4000);                          

begin

    loop
        
        open c_disc (p_invoicedtl_no (v_index), p_item_no (v_index)); 
        fetch c_disc into v_exist;
        close c_disc;

        if v_exist >= 1 then
            for j in c_disc_return (p_invoicedtl_no (v_index), p_item_no (v_index)) loop
                v_disc_index := v_disc_index + 1;
                i_invoicedtl_no  (v_disc_index) := p_invoicedtl_no (v_index);
                i_item_no        (v_disc_index) := p_item_no (v_index);
                i_item_qty       (v_disc_index) := p_item_qty (v_index);
            end loop;  
        end if;
    exit when v_index >= nvl (p_index, 0);
        v_index := v_index + 1;
    end loop;
    
    if v_disc_index > 0 then

        pd_item_disc_cancel(
                             p_invoice_no          => p_invoice_no,
                             p_bill_module_no      => p_bill_module_no,
                             p_disc_time           => 0,
                             p_invoicedtl_no       => i_invoicedtl_no,
                             p_item_no             => i_item_no,
                             p_item_qty            => i_item_qty,
                             p_index               => v_disc_index,
                             p_ss_creator          => p_ss_creator,
                             p_og_no               => p_og_no,
                             p_company_no          => p_company_no,
                             p_ss_created_session  => p_ss_created_session,
                             p_error               => v_error
                             );
        
        if v_error is not null then
            p_error := v_error;
            rollback;
            return;
        end if;
        
    end if;
    
    v_index := 1;
    
    loop
        
        open c_cancel (p_invoicedtl_no (v_index));
        fetch c_cancel into r_c_cancel;
        
        if r_c_cancel.cancel_flag = 1 then
            
            p_error := 'Others user already cancelled '||r_c_cancel.item_name||'. Please check.';
            close c_cancel;
            rollback;
            return;
            
        end if;
        
        if r_c_cancel.act_qty < p_item_qty (v_index) then
            
            p_error := 'Others user already cancelled some item of '||r_c_cancel.item_name||'. Please check.';
            close c_cancel;
            rollback;
            return;
            
        end if;

        v_item_total       := v_item_total + r_c_cancel.item_rate * p_item_qty (v_index);
        v_vat_total        := v_vat_total + r_c_cancel.item_vat * p_item_qty (v_index); 
        v_urg_fee_total    := v_urg_fee_total + r_c_cancel.urgent_fee * p_item_qty (v_index); 
        v_ser_cha_total    := v_ser_cha_total + r_c_cancel.service_charge * p_item_qty (v_index);
    
        if r_c_cancel.item_qty = nvl (r_c_cancel.cancel_qty, 0) + p_item_qty (v_index) then
            
            update opd_invoicedtl
               set cancel_flag = 1,
                   cancel_qty = item_qty,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where opd_invoicedtl_no = p_invoicedtl_no (v_index);
             
             update bill_ledgerdtl
               set cancel_flag = 1,
                   cancel_qty = item_qty,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where invoicedtl_no = p_invoicedtl_no (v_index);
            
        else
            
            update opd_invoicedtl
               set cancel_qty = nvl(cancel_qty,0) + p_item_qty(v_index),
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where opd_invoicedtl_no = p_invoicedtl_no (v_index);
             
             update bill_ledgerdtl
               set cancel_qty = nvl(cancel_qty,0) + p_item_qty(v_index),
                   ss_modifier = p_ss_creator,
                   ss_modified_on = sysdate,
                   ss_modified_session = p_ss_created_session
             where invoicedtl_no = p_invoicedtl_no (v_index);

        end if;
        
        k_general.pd_genarate_no ('SEQ_ADDCANCEL_NO', p_company_no, v_addcancel_no, 'YY', 10);
        
        insert into bill_ledger_addcancel (addcancel_no, invoice_no, invoicedtl_no, 
                                           item_no, item_qty, process_type, process_by, 
                                           process_date, process_datetime, process_reason, bill_module_no,
                                           ss_creator, ss_created_on, ss_created_session, company_no)

        values (v_addcancel_no, p_invoice_no, p_invoicedtl_no (v_index), 
                p_item_no (v_index), p_item_qty (v_index), 0, p_ss_creator, 
                trunc(sysdate), sysdate, p_cancel_reason (v_index), p_bill_module_no,
                p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        close c_cancel;
    exit when v_index >= nvl (p_index, 0);
        v_index := v_index + 1;
    end loop;
    
    v_index := 0;
    
    if v_item_total > 0 then
        
        v_index := v_index + 1;
        
        i_pay_no        (v_index) := null;
        i_pay_mode      (v_index) := null;
        i_coll_mode     (v_index) := null;
        i_pay_type_no   (v_index) := 2;
        i_amount        (v_index) := v_item_total;
        i_given_amt     (v_index) := null;
        
    end if;
    
    if v_vat_total > 0 then
        
        v_index := v_index + 1;
        
        i_pay_no        (v_index) := null;
        i_pay_mode      (v_index) := null;
        i_coll_mode     (v_index) := null;
        i_pay_type_no   (v_index) := 11;
        i_amount        (v_index) := v_vat_total;
        i_given_amt     (v_index) := null;
        
    end if;
    
    if v_urg_fee_total > 0 then
        
        v_index := v_index + 1;
        
        i_pay_no        (v_index) := null;
        i_pay_mode      (v_index) := null;
        i_coll_mode     (v_index) := null;
        i_pay_type_no   (v_index) := 13;
        i_amount        (v_index) := v_urg_fee_total;
        i_given_amt     (v_index) := null;
        
    end if;
    
    if v_ser_cha_total > 0 then
        
        v_index := v_index + 1;
        
        i_pay_no        (v_index) := null;
        i_pay_mode      (v_index) := null;
        i_coll_mode     (v_index) := null;
        i_pay_type_no   (v_index) := 15;
        i_amount        (v_index) := v_ser_cha_total;
        i_given_amt     (v_index) := null;
        
    end if;
    
    if v_item_total > 0 or v_vat_total > 0 or v_urg_fee_total > 0 or v_ser_cha_total > 0 then
    
        k_ledger.pd_ledger (p_reg_no                    => p_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
    
    end if;
        
    if p_error is null and v_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_item_cancel; 

procedure pd_item_disc_cancel(
                              p_invoice_no          in number,
                              p_disc_time           in number,   --0 - all, 1 - initial, 2 - second
                              p_bill_module_no      in number,
                              p_invoicedtl_no       in k_opd.arlist_numb,
                              p_item_no             in k_opd.arlist_numb,
                              p_item_qty            in k_opd.arlist_numb,
                              p_index               in number,
                              p_ss_creator          in number,
                              p_og_no               in number,
                              p_company_no          in number,
                              p_ss_created_session  in number,
                              p_error               out varchar2
                              )
is
    
    cursor c_bill_info
    is
    select opd_invoice_id invoice_id, reg_no, admission_no, admission_id, consultation_no,
           case when admission_no is not null then k_ipd.fd_current_bed_no(admission_no) else null end bed_no
    from opd_invoice
    where opd_invoice_no = p_invoice_no;

    r_c_bill_info c_bill_info%rowtype;
      
    cursor c_disc_ini (p_invoicedtl number, p_item number)
    is
    select disc_type_no,
           sum (nvl (cli_disc_amt, 0) - nvl (cli_disc_ref, 0)) cli_disc,
           sum (nvl (ref_disc_amt, 0) - nvl (ref_disc_ref, 0)) ref_disc
    from bill_paymentdtl pd
    where invoice_no = p_invoice_no
    and item_no = p_item
    and invoicedtl_no = p_invoicedtl
    and exists (select pay_no
                from bill_payment p
                where p.pay_no = pd.pay_no
                and pay_type_no in (6, 8))
    group by disc_type_no
    having sum (nvl (cli_disc_amt, 0) - nvl (cli_disc_ref, 0)) > 0 
        or sum (nvl (ref_disc_amt, 0) - nvl (ref_disc_ref, 0)) > 0
    order by disc_type_no;
    
    cursor c_disc_sec (p_invoicedtl number, p_item number)
    is
    select disc_type_no,
           sum (nvl (cli_disc_amt, 0) - nvl (cli_disc_ref, 0)) cli_disc,
           sum (nvl (ref_disc_amt, 0) - nvl (ref_disc_ref, 0)) ref_disc
    from bill_paymentdtl pd
    where invoice_no = p_invoice_no
    and item_no = p_item
    and invoicedtl_no = p_invoicedtl
    and exists (select pay_no
                from bill_payment p
                where p.pay_no = pd.pay_no
                and pay_type_no in (7, 9))
    group by disc_type_no
    having sum (nvl (cli_disc_amt, 0) - nvl (cli_disc_ref, 0)) > 0 
        or sum (nvl (ref_disc_amt, 0) - nvl (ref_disc_ref, 0)) > 0
    order by disc_type_no;
    
    cursor c_item_qty (p_invoicedtl number, p_item number)
    is
    select item_qty - nvl (cancel_qty, 0) bill_item
    from opd_invoicedtl
    where opd_invoice_no = p_invoice_no 
    and opd_invoicedtl_no = p_invoicedtl
    and item_no = p_item;
    r_c_item_qty c_item_qty%rowtype;
    
    v_index              number := 1;
    
    v_index_ini          number := 0;
    v_index_sec          number := 0;
    
    v_index_pay_ini      number := 1;
    v_index_pay_sec      number := 1;
    
    v_tot_disc_ini          k_financial.arlist_numb;
    v_tot_disc_sec          k_financial.arlist_numb;
    
    v_pay_disc_type_no_ini  k_financial.arlist_numb;
    v_pay_disc_type_no_sec  k_financial.arlist_numb;
    
    v_pay_disc_type_ini     number;
    v_pay_disc_type_sec     number;
    
    v_disc_type_no_ini   k_financial.arlist_numb;
    v_cli_disc_ref_ini   k_financial.arlist_numb;
    v_ref_disc_ref_ini   k_financial.arlist_numb;
    v_disc_type_no_sec   k_financial.arlist_numb;
    v_cli_disc_ref_sec   k_financial.arlist_numb;
    v_ref_disc_ref_sec   k_financial.arlist_numb;
    
    v_item_no_ini        k_financial.arlist_numb;
    v_item_no_sec        k_financial.arlist_numb;
    v_invoicedtl_no_ini  k_financial.arlist_numb;
    v_invoicedtl_no_sec  k_financial.arlist_numb;
     
    p_pay_mode           k_financial.arlist_numb;
    p_coll_mode          k_financial.arlist_numb;
    p_pay_type_no        k_financial.arlist_numb;
    p_pay_cqcc_others    k_financial.arlist_varc;
    p_pay_bank_name      k_financial.arlist_varc;
    p_amount             k_financial.arlist_numb;
    p_given_amt          k_financial.arlist_numb;  
    
    i_pay_no             k_ledger.arlist_numb;
    i_pay_mode           k_ledger.arlist_numb;
    i_coll_mode          k_ledger.arlist_numb;
    i_pay_type_no        k_ledger.arlist_numb;
    i_amount             k_ledger.arlist_numb;
    i_given_amt          k_ledger.arlist_numb; 
    
    v_pay_no            number;
    v_pay_id            varchar2(50);
    v_paydtl_no         number;
    
begin

    if p_disc_time = 0 then
        
        v_index := 1;
        
        loop
            
            for r_c_disc_ini in c_disc_ini (p_invoicedtl_no (v_index), p_item_no (v_index)) loop
                
                v_index_ini := v_index_ini + 1;
                
                open c_item_qty (p_invoicedtl_no (v_index), p_item_no (v_index));
                fetch c_item_qty into r_c_item_qty;
                close c_item_qty;
                
                if r_c_item_qty.bill_item <> p_item_qty (v_index) then

                    if r_c_disc_ini.cli_disc > 0 then
                        v_cli_disc_ref_ini (v_index_ini) := nvl (round (r_c_disc_ini.cli_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_cli_disc_ref_ini (v_index_ini) := 0;    
                    end if;
                    
                    if r_c_disc_ini.ref_disc > 0 then
                        v_ref_disc_ref_ini (v_index_ini) := nvl (round (r_c_disc_ini.ref_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_ref_disc_ref_ini (v_index_ini) := 0;
                    end if;
                    
                    v_disc_type_no_ini (v_index_ini) := r_c_disc_ini.disc_type_no;
                    v_item_no_ini      (v_index_ini) := p_item_no (v_index);
                    v_invoicedtl_no_ini(v_index_ini) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_ini is null then    
                        
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                    
                    else 
                      
                        if v_pay_disc_type_ini = r_c_disc_ini.disc_type_no then
                            v_tot_disc_ini (v_index_pay_ini) := v_tot_disc_ini (v_index_pay_ini) + v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);    
                        else
                            v_index_pay_ini := v_index_pay_ini + 1;
                            v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                            v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                            v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                        end if;    
                    
                    end if;
                
                else

                    v_cli_disc_ref_ini (v_index_ini) := nvl (r_c_disc_ini.cli_disc, 0);
                    v_ref_disc_ref_ini (v_index_ini) := nvl (r_c_disc_ini.ref_disc, 0);
                    
                    v_disc_type_no_ini (v_index_ini) := r_c_disc_ini.disc_type_no;
                    v_item_no_ini      (v_index_ini) := p_item_no (v_index);
                    v_invoicedtl_no_ini(v_index_ini) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_ini is null then    
                     
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                    
                    else   
                        
                        if v_pay_disc_type_ini = r_c_disc_ini.disc_type_no then
                            v_tot_disc_ini (v_index_pay_ini) := v_tot_disc_ini (v_index_pay_ini) + v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);    
                        else
                            v_index_pay_ini := v_index_pay_ini + 1;
                            v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                            v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                            v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                        end if; 
                           
                    end if;
                end if;
            
            end loop;

        exit when v_index >= nvl (p_index, 0);
            v_index := v_index + 1;
        end loop;

        v_index := 1;     
        
        loop
            
            for r_c_disc_sec in c_disc_sec (p_invoicedtl_no (v_index), p_item_no (v_index)) loop
                
                v_index_sec := v_index_sec + 1;
                
                open c_item_qty (p_invoicedtl_no (v_index), p_item_no (v_index));
                fetch c_item_qty into r_c_item_qty;
                close c_item_qty;
                
                if r_c_item_qty.bill_item <> p_item_qty (v_index) then

                    if r_c_disc_sec.cli_disc > 0 then
                        v_cli_disc_ref_sec (v_index_sec) := nvl (round (r_c_disc_sec.cli_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_cli_disc_ref_sec (v_index_sec) := 0;    
                    end if;
                    
                    if r_c_disc_sec.ref_disc > 0 then
                        v_ref_disc_ref_sec (v_index_sec) := nvl (round (r_c_disc_sec.ref_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_ref_disc_ref_sec (v_index_sec) := 0;
                    end if;
                    
                    v_disc_type_no_sec (v_index_sec) := r_c_disc_sec.disc_type_no;
                    v_item_no_sec      (v_index_sec) := p_item_no (v_index);
                    v_invoicedtl_no_sec(v_index_sec) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_sec is null then    
                        
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                    
                    else 
                      
                        if v_pay_disc_type_sec = r_c_disc_sec.disc_type_no then
                            v_tot_disc_sec (v_index_pay_sec) := v_tot_disc_sec (v_index_pay_sec) + v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);    
                        else
                            v_index_pay_sec := v_index_pay_sec + 1;
                            v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                            v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                            v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                        end if;    
                    
                    end if;
                
                else

                    v_cli_disc_ref_sec (v_index_sec) := nvl (r_c_disc_sec.cli_disc, 0);
                    v_ref_disc_ref_sec (v_index_sec) := nvl (r_c_disc_sec.ref_disc, 0);
                    
                    v_disc_type_no_sec (v_index_sec) := r_c_disc_sec.disc_type_no;
                    v_item_no_sec      (v_index_sec) := p_item_no (v_index);
                    v_invoicedtl_no_sec(v_index_sec) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_sec is null then    
                     
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                    
                    else   
                        
                        if v_pay_disc_type_sec = r_c_disc_sec.disc_type_no then
                            v_tot_disc_sec (v_index_pay_sec) := v_tot_disc_sec (v_index_pay_sec) + v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);    
                        else
                            v_index_pay_sec := v_index_pay_sec + 1;
                            v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                            v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                            v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                        end if; 
                           
                    end if;
                end if;
            
            end loop;

        exit when v_index >= nvl (p_index, 0);
            v_index := v_index + 1;
        end loop;
    
    elsif p_disc_time = 1 then
        
        v_index := 1;
        
        loop
            
            for r_c_disc_ini in c_disc_ini (p_invoicedtl_no (v_index), p_item_no (v_index)) loop
                
                v_index_ini := v_index_ini + 1;
                
                open c_item_qty (p_invoicedtl_no (v_index), p_item_no (v_index));
                fetch c_item_qty into r_c_item_qty;
                close c_item_qty;
                
                if r_c_item_qty.bill_item <> p_item_qty (v_index) then

                    if r_c_disc_ini.cli_disc > 0 then
                        v_cli_disc_ref_ini (v_index_ini) := nvl (round (r_c_disc_ini.cli_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_cli_disc_ref_ini (v_index_ini) := 0;    
                    end if;
                    
                    if r_c_disc_ini.ref_disc > 0 then
                        v_ref_disc_ref_ini (v_index_ini) := nvl (round (r_c_disc_ini.ref_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_ref_disc_ref_ini (v_index_ini) := 0;
                    end if;
                    
                    v_disc_type_no_ini (v_index_ini) := r_c_disc_ini.disc_type_no;
                    v_item_no_ini      (v_index_ini) := p_item_no (v_index);
                    v_invoicedtl_no_ini(v_index_ini) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_ini is null then    
                        
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                    
                    else 
                      
                        if v_pay_disc_type_ini = r_c_disc_ini.disc_type_no then
                            v_tot_disc_ini (v_index_pay_ini) := v_tot_disc_ini (v_index_pay_ini) + v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);    
                        else
                            v_index_pay_ini := v_index_pay_ini + 1;
                            v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                            v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                            v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                        end if;    
                    
                    end if;
                
                else

                    v_cli_disc_ref_ini (v_index_ini) := nvl (r_c_disc_ini.cli_disc, 0);
                    v_ref_disc_ref_ini (v_index_ini) := nvl (r_c_disc_ini.ref_disc, 0);
                    
                    v_disc_type_no_ini (v_index_ini) := r_c_disc_ini.disc_type_no;
                    v_item_no_ini      (v_index_ini) := p_item_no (v_index);
                    v_invoicedtl_no_ini(v_index_ini) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_ini is null then    
                     
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                    
                    else   
                        
                        if v_pay_disc_type_ini = r_c_disc_ini.disc_type_no then
                            v_tot_disc_ini (v_index_pay_ini) := v_tot_disc_ini (v_index_pay_ini) + v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);    
                        else
                            v_index_pay_ini := v_index_pay_ini + 1;
                            v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                            v_pay_disc_type_no_ini (v_index_pay_ini) := r_c_disc_ini.disc_type_no;
                            v_tot_disc_ini (v_index_pay_ini) := v_cli_disc_ref_ini (v_index_ini) + v_ref_disc_ref_ini (v_index_ini);
                        end if; 
                           
                    end if;
                end if;
            
            end loop;

        exit when v_index >= nvl (p_index, 0);
            v_index := v_index + 1;
        end loop;
        
    elsif p_disc_time = 2 then
        
        v_index := 1;     
        
        loop
            
            for r_c_disc_sec in c_disc_sec (p_invoicedtl_no (v_index), p_item_no (v_index)) loop
                
                v_index_sec := v_index_sec + 1;
                
                open c_item_qty (p_invoicedtl_no (v_index), p_item_no (v_index));
                fetch c_item_qty into r_c_item_qty;
                close c_item_qty;
                
                if r_c_item_qty.bill_item <> p_item_qty (v_index) then

                    if r_c_disc_sec.cli_disc > 0 then
                        v_cli_disc_ref_sec (v_index_sec) := nvl (round (r_c_disc_sec.cli_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_cli_disc_ref_sec (v_index_sec) := 0;    
                    end if;
                    
                    if r_c_disc_sec.ref_disc > 0 then
                        v_ref_disc_ref_sec (v_index_sec) := nvl (round (r_c_disc_sec.ref_disc / r_c_item_qty.bill_item * p_item_qty (v_index)),0);
                    else
                        v_ref_disc_ref_sec (v_index_sec) := 0;
                    end if;
                    
                    v_disc_type_no_sec (v_index_sec) := r_c_disc_sec.disc_type_no;
                    v_item_no_sec      (v_index_sec) := p_item_no (v_index);
                    v_invoicedtl_no_sec(v_index_sec) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_sec is null then    
                        
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                    
                    else 
                      
                        if v_pay_disc_type_sec = r_c_disc_sec.disc_type_no then
                            v_tot_disc_sec (v_index_pay_sec) := v_tot_disc_sec (v_index_pay_sec) + v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);    
                        else
                            v_index_pay_sec := v_index_pay_sec + 1;
                            v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                            v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                            v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                        end if;    
                    
                    end if;
                
                else

                    v_cli_disc_ref_sec (v_index_sec) := nvl (r_c_disc_sec.cli_disc, 0);
                    v_ref_disc_ref_sec (v_index_sec) := nvl (r_c_disc_sec.ref_disc, 0);
                    
                    v_disc_type_no_sec (v_index_sec) := r_c_disc_sec.disc_type_no;
                    v_item_no_sec      (v_index_sec) := p_item_no (v_index);
                    v_invoicedtl_no_sec(v_index_sec) := p_invoicedtl_no (v_index);
                    
                    if v_pay_disc_type_sec is null then    
                     
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                    
                    else   
                        
                        if v_pay_disc_type_sec = r_c_disc_sec.disc_type_no then
                            v_tot_disc_sec (v_index_pay_sec) := v_tot_disc_sec (v_index_pay_sec) + v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);    
                        else
                            v_index_pay_sec := v_index_pay_sec + 1;
                            v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                            v_pay_disc_type_no_sec (v_index_pay_sec) := r_c_disc_sec.disc_type_no;
                            v_tot_disc_sec (v_index_pay_sec) := v_cli_disc_ref_sec (v_index_sec) + v_ref_disc_ref_sec (v_index_sec);
                        end if; 
                           
                    end if;
                end if;
            
            end loop;
        
        exit when v_index >= nvl (p_index, 0);
            v_index := v_index + 1;
        end loop;
        
    end if;
    
    open c_bill_info;
    fetch c_bill_info into r_c_bill_info;
    close c_bill_info;
    
    if p_disc_time = 0 then
        
        v_index := 1;
        
        if v_pay_disc_type_ini is not null then

            for i in 1..v_index_pay_ini loop
            
                p_pay_mode           (i) := null;
                p_coll_mode          (i) := null;
                p_pay_type_no        (i) := 8;
                p_pay_cqcc_others    (i) := null;
                p_pay_bank_name      (i) := null;
                p_amount             (i) := v_tot_disc_ini (i);
                p_given_amt          (i) := null;  
                
                k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
                k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);  
                
                insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, 
                                         reg_no, invoice_no, admission_no, disc_type_no, 
                                         pay_amt, pay_type_no, bill_module_no,
                                         ss_creator, ss_created_on, ss_created_session, company_no)
                values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 
                       r_c_bill_info.reg_no, p_invoice_no, r_c_bill_info.admission_no, v_pay_disc_type_no_ini (i), 
                       p_amount(i), p_pay_type_no(i), p_bill_module_no,
                       p_ss_creator, sysdate, p_ss_created_session, p_company_no); 

                v_index := 1;
                
                loop
                    
                    if v_pay_disc_type_no_ini (i) = v_disc_type_no_ini (v_index) then
                    
                        k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY', 10);    
                        
                        insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                                     reg_no, invoice_no, invoicedtl_no, admission_no, 
                                                     item_no, bill_module_no, disc_type_no, cli_disc_ref, ref_disc_ref, 
                                                     ss_creator, ss_created_on, ss_created_session, company_no)
                        values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                               r_c_bill_info.reg_no, p_invoice_no, v_invoicedtl_no_ini (v_index), r_c_bill_info.admission_no,
                               v_item_no_ini (v_index), p_bill_module_no, v_disc_type_no_ini (v_index), v_cli_disc_ref_ini (v_index), v_ref_disc_ref_ini (v_index), 
                               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
                    end if;  
                      
                exit when v_index >= nvl (v_index_ini, 0);
                    v_index := v_index + 1; 
                end loop;
                
                i_pay_no             (i) := v_pay_no;
                i_pay_mode           (i) := null;
                i_coll_mode          (i) := null;
                i_pay_type_no        (i) := 8;
                i_amount             (i) := p_amount(i);
                i_given_amt          (i) := null;
                
                k_ledger.pd_ledger (p_reg_no                    => r_c_bill_info.reg_no,
                                    p_invoice_no                => p_invoice_no,
                                    p_invoice_id                => r_c_bill_info.invoice_id,
                                    p_bill_module_no            => p_bill_module_no,
                                    p_admission_no              => r_c_bill_info.admission_no,
                                    p_admission_id              => r_c_bill_info.admission_id,
                                    p_consultation_no           => r_c_bill_info.consultation_no,
                                    p_pay_no                    => i_pay_no,
                                    p_pay_mode                  => i_pay_mode,
                                    p_coll_mode                 => i_coll_mode,
                                    p_pay_type_no               => i_pay_type_no,
                                    p_amount                    => i_amount,
                                    p_given_amt                 => i_given_amt,
                                    p_index                     => 1,
                                    p_disctype_no               => v_pay_disc_type_no_ini (i),  
                                    p_disc_auth_by              => null,
                                    p_bed_no                    => r_c_bill_info.bed_no,
                                    p_ss_creator                => p_ss_creator,
                                    p_og_no                     => p_og_no,
                                    p_company_no                => p_company_no,
                                    p_ss_created_session        => p_ss_created_session,
                                    p_error                     => p_error
                                    );
                            
            end loop;
        
        end if;
             
        v_index := 1;
        
        if v_pay_disc_type_sec is not null then
        
            for i in 1..v_index_pay_sec loop
            
                p_pay_mode           (i) := null;
                p_coll_mode          (i) := null;
                p_pay_type_no        (i) := 9;
                p_pay_cqcc_others    (i) := null;
                p_pay_bank_name      (i) := null;
                p_amount             (i) := v_tot_disc_sec (i);
                p_given_amt          (i) := null;  
                
                k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
                k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);  
                
                insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, 
                                         reg_no, invoice_no, admission_no, disc_type_no, 
                                         pay_amt, pay_type_no, bill_module_no,
                                         ss_creator, ss_created_on, ss_created_session, company_no)
                values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 
                       r_c_bill_info.reg_no, p_invoice_no, r_c_bill_info.admission_no, v_pay_disc_type_no_sec (i), 
                       p_amount(i), p_pay_type_no(i), p_bill_module_no,
                       p_ss_creator, sysdate, p_ss_created_session, p_company_no); 
                
                v_index := 1;
                
                loop
                    
                    if v_pay_disc_type_no_sec (i) = v_disc_type_no_sec (v_index) then
                    
                        k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY', 10);    
                        
                        insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                                     reg_no, invoice_no, invoicedtl_no, admission_no, 
                                                     item_no, bill_module_no, disc_type_no, cli_disc_ref, ref_disc_ref, 
                                                     ss_creator, ss_created_on, ss_created_session, company_no)
                        values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                               r_c_bill_info.reg_no, p_invoice_no, v_invoicedtl_no_sec (v_index), r_c_bill_info.admission_no,
                               v_item_no_sec (v_index), p_bill_module_no, v_disc_type_no_sec (v_index), v_cli_disc_ref_sec (v_index), v_ref_disc_ref_sec (v_index), 
                               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
                    end if;  
                      
                exit when v_index >= nvl (v_index_sec, 0);
                    v_index := v_index + 1; 
                end loop;
                
                i_pay_no             (i) := v_pay_no;
                i_pay_mode           (i) := null;
                i_coll_mode          (i) := null;
                i_pay_type_no        (i) := 9;
                i_amount             (i) := p_amount(i);
                i_given_amt          (i) := null;
                
                k_ledger.pd_ledger (p_reg_no                    => r_c_bill_info.reg_no,
                                    p_invoice_no                => p_invoice_no,
                                    p_invoice_id                => r_c_bill_info.invoice_id,
                                    p_bill_module_no            => p_bill_module_no,
                                    p_admission_no              => r_c_bill_info.admission_no,
                                    p_admission_id              => r_c_bill_info.admission_id,
                                    p_consultation_no           => r_c_bill_info.consultation_no,
                                    p_pay_no                    => i_pay_no,
                                    p_pay_mode                  => i_pay_mode,
                                    p_coll_mode                 => i_coll_mode,
                                    p_pay_type_no               => i_pay_type_no,
                                    p_amount                    => i_amount,
                                    p_given_amt                 => i_given_amt,
                                    p_index                     => 1,
                                    p_disctype_no               => v_pay_disc_type_no_sec (i),  
                                    p_disc_auth_by              => null,
                                    p_bed_no                    => r_c_bill_info.bed_no,
                                    p_ss_creator                => p_ss_creator,
                                    p_og_no                     => p_og_no,
                                    p_company_no                => p_company_no,
                                    p_ss_created_session        => p_ss_created_session,
                                    p_error                     => p_error
                                    );
                            
            end loop;
        
        end if;
        
    elsif p_disc_time = 1 then
        
        v_index := 1;
        
        if v_pay_disc_type_ini is not null then

            for i in 1..v_index_pay_ini loop
            
                p_pay_mode           (i) := null;
                p_coll_mode          (i) := null;
                p_pay_type_no        (i) := 8;
                p_pay_cqcc_others    (i) := null;
                p_pay_bank_name      (i) := null;
                p_amount             (i) := v_tot_disc_ini (i);
                p_given_amt          (i) := null;  
                
                k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
                k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);  
                
                insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, 
                                         reg_no, invoice_no, admission_no, disc_type_no, 
                                         pay_amt, pay_type_no, bill_module_no,
                                         ss_creator, ss_created_on, ss_created_session, company_no)
                values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 
                       r_c_bill_info.reg_no, p_invoice_no, r_c_bill_info.admission_no, v_pay_disc_type_no_ini (i), 
                       p_amount(i), p_pay_type_no(i), p_bill_module_no,
                       p_ss_creator, sysdate, p_ss_created_session, p_company_no); 

                v_index := 1;
                
                loop
                    
                    if v_pay_disc_type_no_ini (i) = v_disc_type_no_ini (v_index) then
                    
                        k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY', 10);    
                        
                        insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                                     reg_no, invoice_no, invoicedtl_no, admission_no, 
                                                     item_no, bill_module_no, disc_type_no, cli_disc_ref, ref_disc_ref, 
                                                     ss_creator, ss_created_on, ss_created_session, company_no)
                        values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                               r_c_bill_info.reg_no, p_invoice_no, v_invoicedtl_no_ini (v_index), r_c_bill_info.admission_no,
                               v_item_no_ini (v_index), p_bill_module_no, v_disc_type_no_ini (v_index), v_cli_disc_ref_ini (v_index), v_ref_disc_ref_ini (v_index), 
                               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
                    end if;  
                      
                exit when v_index >= nvl (v_index_ini, 0);
                    v_index := v_index + 1; 
                end loop;
                
                i_pay_no             (i) := v_pay_no;
                i_pay_mode           (i) := null;
                i_coll_mode          (i) := null;
                i_pay_type_no        (i) := 8;
                i_amount             (i) := p_amount(i);
                i_given_amt          (i) := null;
                
                k_ledger.pd_ledger (p_reg_no                    => r_c_bill_info.reg_no,
                                    p_invoice_no                => p_invoice_no,
                                    p_invoice_id                => r_c_bill_info.invoice_id,
                                    p_bill_module_no            => p_bill_module_no,
                                    p_admission_no              => r_c_bill_info.admission_no,
                                    p_admission_id              => r_c_bill_info.admission_id,
                                    p_consultation_no           => r_c_bill_info.consultation_no,
                                    p_pay_no                    => i_pay_no,
                                    p_pay_mode                  => i_pay_mode,
                                    p_coll_mode                 => i_coll_mode,
                                    p_pay_type_no               => i_pay_type_no,
                                    p_amount                    => i_amount,
                                    p_given_amt                 => i_given_amt,
                                    p_index                     => 1,
                                    p_disctype_no               => v_pay_disc_type_no_ini (i),  
                                    p_disc_auth_by              => null,
                                    p_bed_no                    => r_c_bill_info.bed_no,
                                    p_ss_creator                => p_ss_creator,
                                    p_og_no                     => p_og_no,
                                    p_company_no                => p_company_no,
                                    p_ss_created_session        => p_ss_created_session,
                                    p_error                     => p_error
                                    );
                            
            end loop;
        
        end if;
    
    elsif p_disc_time = 2 then
        
        v_index := 1;
        
        if v_pay_disc_type_sec is not null then
        
            for i in 1..v_index_pay_sec loop
            
                p_pay_mode           (i) := null;
                p_coll_mode          (i) := null;
                p_pay_type_no        (i) := 9;
                p_pay_cqcc_others    (i) := null;
                p_pay_bank_name      (i) := null;
                p_amount             (i) := v_tot_disc_sec (i);
                p_given_amt          (i) := null;  
                
                k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
                k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);  
                
                insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, 
                                         reg_no, invoice_no, admission_no, disc_type_no, 
                                         pay_amt, pay_type_no, bill_module_no,
                                         ss_creator, ss_created_on, ss_created_session, company_no)
                values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 
                       r_c_bill_info.reg_no, p_invoice_no, r_c_bill_info.admission_no, v_pay_disc_type_no_sec (i), 
                       p_amount(i), p_pay_type_no(i), p_bill_module_no,
                       p_ss_creator, sysdate, p_ss_created_session, p_company_no); 
                
                v_index := 1;
                
                loop
                    
                    if v_pay_disc_type_no_sec (i) = v_disc_type_no_sec (v_index) then
                    
                        k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY', 10);    
                        
                        insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                                     reg_no, invoice_no, invoicedtl_no, admission_no, 
                                                     item_no, bill_module_no, disc_type_no, cli_disc_ref, ref_disc_ref, 
                                                     ss_creator, ss_created_on, ss_created_session, company_no)
                        values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                               r_c_bill_info.reg_no, p_invoice_no, v_invoicedtl_no_sec (v_index), r_c_bill_info.admission_no,
                               v_item_no_sec (v_index), p_bill_module_no, v_disc_type_no_sec (v_index), v_cli_disc_ref_sec (v_index), v_ref_disc_ref_sec (v_index), 
                               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
                    end if;  
                      
                exit when v_index >= nvl (v_index_sec, 0);
                    v_index := v_index + 1; 
                end loop;
                
                i_pay_no             (i) := v_pay_no;
                i_pay_mode           (i) := null;
                i_coll_mode          (i) := null;
                i_pay_type_no        (i) := 9;
                i_amount             (i) := p_amount(i);
                i_given_amt          (i) := null;
                
                k_ledger.pd_ledger (p_reg_no                    => r_c_bill_info.reg_no,
                                    p_invoice_no                => p_invoice_no,
                                    p_invoice_id                => r_c_bill_info.invoice_id,
                                    p_bill_module_no            => p_bill_module_no,
                                    p_admission_no              => r_c_bill_info.admission_no,
                                    p_admission_id              => r_c_bill_info.admission_id,
                                    p_consultation_no           => r_c_bill_info.consultation_no,
                                    p_pay_no                    => i_pay_no,
                                    p_pay_mode                  => i_pay_mode,
                                    p_coll_mode                 => i_coll_mode,
                                    p_pay_type_no               => i_pay_type_no,
                                    p_amount                    => i_amount,
                                    p_given_amt                 => i_given_amt,
                                    p_index                     => 1,
                                    p_disctype_no               => v_pay_disc_type_no_sec (i),  
                                    p_disc_auth_by              => null,
                                    p_bed_no                    => r_c_bill_info.bed_no,
                                    p_ss_creator                => p_ss_creator,
                                    p_og_no                     => p_og_no,
                                    p_company_no                => p_company_no,
                                    p_ss_created_session        => p_ss_created_session,
                                    p_error                     => p_error
                                    );
                            
            end loop;
        
        end if;
            
    end if;  

    if p_error is null then
        commit;     
    else
        rollback;
    end if;
         
exception when others then 
    p_error := sqlerrm;
end pd_item_disc_cancel;

procedure pd_invoice_cancel(
                            p_invoice_no          in number,
                            p_bill_module_no      in number,
                            p_item_no             in k_opd.arlist_numb,              
                            p_invoicedtl_no       in k_opd.arlist_numb, 
                            p_item_qty            in k_opd.arlist_numb, 
                            p_itemtype_no         in k_opd.arlist_numb,
                            p_cancel_reason       in k_opd.arlist_varc, 
                            p_index               in number,
                            p_ss_creator          in number,
                            p_og_no               in number,
                            p_company_no          in number,
                            p_ss_created_session  in number,
                            p_error               out varchar2
                            )
is
    
    v_index number := 1;
    i_invoicedtl_no       k_opd.arlist_numb;
    i_item_no             k_opd.arlist_numb;
    i_item_qty            k_opd.arlist_numb;
    i_itemtype_no         k_opd.arlist_numb;
    i_cancel_reason       k_opd.arlist_varc;
    
    cursor c_bill_info
    is
    select o.opd_invoice_id invoice_id, o.reg_no, o.admission_no, o.admission_id, o.consultation_no,
           case when admission_no is not null then k_ipd.fd_current_bed_no(admission_no) else null end bed_no, o.invoice_cancel_flag,
           v.total_pay_amt, o.ss_creator
    from opd_invoice o, opd_invoice_status_v v
    where o.opd_invoice_no = v.invoice_no
    and o.opd_invoice_no = p_invoice_no
    for update of invoice_cancel_flag wait 60;
    r_c_bill_info c_bill_info%rowtype;
    
    
    cursor c_config
    is
    select nvl(con_auto_refund,0) con_auto_refund
    from opd_config
    where company_no = p_company_no;
    r_c_config  c_config%rowtype;
    
    
    i_pay_mode            k_opd.arlist_numb;
    i_coll_mode           k_opd.arlist_numb;
    i_pay_type_no         k_opd.arlist_numb;
    i_pay_cqcc_others     k_opd.arlist_varc;
    i_pay_bank_name       k_opd.arlist_varc;
    i_pay_amt             k_opd.arlist_numb;
    i_given_amt           k_opd.arlist_numb;
    v_ss_creator          number;

              
begin
    
    open c_bill_info;
    fetch c_bill_info into r_c_bill_info;
    if r_c_bill_info.invoice_cancel_flag = 1 then
        
        p_error := 'Other user already cancelled this invoice. Please check.';
        close c_bill_info;
        return;
        
    end if;
    
    loop
    
        i_invoicedtl_no       (v_index) := p_invoicedtl_no (v_index);
        i_item_no             (v_index) := p_item_no (v_index);
        i_item_qty            (v_index) := p_item_qty (v_index);
        i_itemtype_no         (v_index) := p_itemtype_no (v_index);
        i_cancel_reason       (v_index) := p_cancel_reason (v_index);
        
    exit when v_index >= nvl (p_index, 0);
            v_index := v_index + 1; 
    end loop;
    
    pd_item_cancel(
                  p_invoice_no          => p_invoice_no,
                  p_invoice_id          => r_c_bill_info.invoice_id, 
                  p_reg_no              => r_c_bill_info.reg_no, 
                  p_admission_no        => r_c_bill_info.admission_no, 
                  p_admission_id        => r_c_bill_info.admission_id,
                  p_bed_no              => r_c_bill_info.bed_no, 
                  p_consultation_no     => r_c_bill_info.consultation_no,
                  p_bill_module_no      => p_bill_module_no,
                  p_invoicedtl_no       => i_invoicedtl_no,
                  p_item_no             => i_item_no,
                  p_item_qty            => i_item_qty,
                  p_itemtype_no         => i_itemtype_no,
                  p_cancel_reason       => i_cancel_reason,
                  p_index               => v_index,
                  p_ss_creator          => p_ss_creator,
                  p_og_no               => p_og_no,
                  p_company_no          => p_company_no,
                  p_ss_created_session  => p_ss_created_session,
                  p_error               => p_error
                  );
    
    
    open c_config;
    fetch c_config into r_c_config;
    close c_config;
    
    if r_c_config.con_auto_refund = 1 and p_bill_module_no <> 12 then 
    
            i_pay_mode            (1) := 1;
            i_coll_mode           (1) := 1;
            i_pay_type_no         (1) := 5;
            i_pay_cqcc_others     (1) := null;
            i_pay_bank_name       (1) := null;
            i_pay_amt             (1) := r_c_bill_info.total_pay_amt;
            i_given_amt           (1) := null;
            
            if p_og_no <> 98 then 
                v_ss_creator := p_ss_creator;
            else
                v_ss_creator := r_c_bill_info.ss_creator;
            end if;
            
            
            pd_refund (
                      p_invoice_no          => p_invoice_no,
                      p_invoice_id          => r_c_bill_info.invoice_id,
                      p_reg_no              => r_c_bill_info.reg_no,
                      p_admission_no        => r_c_bill_info.admission_no,
                      p_admission_id        => r_c_bill_info.admission_id,
                      p_bed_no              => r_c_bill_info.bed_no,
                      p_consultation_no     => r_c_bill_info.consultation_no,
                      p_bill_module_no      => p_bill_module_no,
                      p_pay_mode            => i_pay_mode,
                      p_coll_mode           => i_coll_mode,
                      p_pay_type_no         => i_pay_type_no,
                      p_pay_cqcc_others     => i_pay_cqcc_others,
                      p_pay_bank_name       => i_pay_bank_name,
                      p_pay_amt             => i_pay_amt,
                      p_given_amt           => i_given_amt,
                      p_pay_index           => 1,
                      p_pay_remarks         => null,
                      p_ss_creator          => nvl(v_ss_creator,p_ss_creator),
                      p_og_no               => p_og_no,
                      p_company_no          => p_company_no,
                      p_ss_created_session  => p_ss_created_session,
                      p_error               => p_error
                     );
    else
       null;              
    end if;                 
                             
    update opd_invoice
    set invoice_cancel_flag = 1, 
        invoice_cancel_remark = p_cancel_reason(1),
        ss_modifier = p_ss_creator,
        ss_modified_on = sysdate,
        ss_modified_session = p_ss_created_session
    where opd_invoice_no = p_invoice_no;    
    
    update bill_ledgermst
    set invoice_cancel_flag = 1, 
        ss_modifier = p_ss_creator,
        ss_modified_on = sysdate,
        ss_modified_session = p_ss_created_session
    where invoice_no = p_invoice_no;
    
    if r_c_bill_info.consultation_no is not null then

        update opd_consultation
        set cancel_flag = 1, 
            cancel_reason = p_cancel_reason(1),
            ss_modifier = p_ss_creator,
            ss_modified_on = sysdate,
            ss_modified_session = p_ss_created_session
        where opd_consultation_no = r_c_bill_info.consultation_no;
    end if;
        
    close c_bill_info;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then 
    p_error := sqlerrm;
end pd_invoice_cancel;

procedure pd_refund (
                      p_invoice_no          in number,
                      p_invoice_id          in varchar2,
                      p_reg_no              in number,
                      p_admission_no        in number   default null,
                      p_admission_id        in varchar2 default null,
                      p_bed_no              in number   default null,
                      p_consultation_no     in number   default null,
                      p_bill_module_no      in number,
                      p_pay_mode            in k_opd.arlist_numb,
                      p_coll_mode           in k_opd.arlist_numb,
                      p_pay_type_no         in k_opd.arlist_numb,
                      p_pay_cqcc_others     in k_opd.arlist_varc,
                      p_pay_bank_name       in k_opd.arlist_varc,
                      p_pay_amt             in k_opd.arlist_numb,
                      p_given_amt           in k_opd.arlist_numb,
                      p_pay_index           in number,
                      p_pay_remarks         in varchar2,
                      p_ss_creator          in number,
                      p_og_no               in number,
                      p_company_no          in number,
                      p_ss_created_session  in number,
                      p_error               out varchar2
                     )
is
    
    v_pay_index         number := 1;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
begin
    
    if nvl(p_pay_index,0) > 0 then
    
        loop
        
            k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
            k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);
            
            insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                      reg_no, invoice_no, admission_no, pay_amt, 
                                      pay_type_no, pay_mode, coll_mode, pay_cqcc_others, 
                                      pay_bank_name, given_amt, pay_remarks, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
            values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
                   p_reg_no, p_invoice_no, p_admission_no, p_pay_amt (v_pay_index), 
                   p_pay_type_no (v_pay_index), p_pay_mode (v_pay_index), p_coll_mode (v_pay_index), p_pay_cqcc_others (v_pay_index), 
                   p_pay_bank_name (v_pay_index), p_given_amt (v_pay_index), p_pay_remarks,  p_ss_creator, 
                   sysdate, p_ss_created_session, p_company_no);
        
            i_pay_no        (v_pay_index) := v_pay_no;
            i_pay_mode      (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode     (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no   (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount        (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt     (v_pay_index) := p_given_amt (v_pay_index);
                
        exit when v_pay_index >= nvl (p_pay_index, 0);
            v_pay_index := v_pay_index + 1; 
        end loop;

        k_ledger.pd_ledger (p_reg_no                    => p_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_pay_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
                    
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_refund;
 
procedure pd_ambulance_invoice (
                      p_reg_no                    in       number default null,
                      p_hospital_number           in       varchar2 default null,
                      p_pat_type_no               in       number default null,
                      p_admission_no              in       number default null,
                      p_admission_id              in       varchar2 default null,
                      p_consultation_no           in       number default null,
                      p_bed_no                    in       number default null,
                      p_salutation                in       varchar2,
                      p_fname                     in       varchar2,
                      p_lname                     in       varchar2,
                      p_gender                    in       varchar2,
                      p_m_status                  in       varchar2,
                      p_age_dd                    in       number,
                      p_age_mm                    in       number,
                      p_age_yy                    in       number,
                      p_phone_mobile              in       varchar2,
                      p_dob                       in       date default null,
                      p_address                   in       varchar2 default null,
                      p_blood_group               in       varchar2 default null,
                      p_religion                  in       varchar2 default null,
                      p_email                     in       varchar2 default null,
                      p_national_id               in       varchar2 default null,
                      p_ref_doc_no                in       number default null,
                      p_remarks                   in       varchar2 default null,
                      p_delivery_date             in       date default null,
                      p_item_no                   in       k_opd.arlist_numb,
                      p_item_name                 in       k_opd.arlist_varc,
                      p_item_qty                  in       k_opd.arlist_numb,
                      p_item_rate                 in       k_opd.arlist_numb,
                      p_item_vat                  in       k_opd.arlist_numb,
                      p_urgent_fee                in       k_opd.arlist_numb,
                      p_service_charge            in       k_opd.arlist_numb,
                      p_itemtype_no               in       k_opd.arlist_numb,
                      p_par_itemtype_no           in       k_opd.arlist_numb,
                      p_bu_no                     in       k_opd.arlist_numb,
                      p_delivery_status_no        in       k_opd.arlist_numb,
                      p_package_item_flag         in       k_opd.arlist_numb,
                      p_cli_disc_amt              in       k_opd.arlist_numb,
                      p_item_index                in       number,
                      p_cor_client_no             in       number default null,
                      p_cor_client_emp_id         in       varchar2 default null,
                      p_emp_no                    in       number default null,
                      p_relation_no               in       number default null,
                      p_pay_mode                  in       k_opd.arlist_numb,
                      p_coll_mode                 in       k_opd.arlist_numb,
                      p_pay_type_no               in       k_opd.arlist_numb,
                      p_pay_cqcc_others           in       k_opd.arlist_varc,
                      p_pay_bank_name             in       k_opd.arlist_varc,
                      p_pay_amt                   in       k_opd.arlist_numb,
                      p_given_amt                 in       k_opd.arlist_numb,
                      p_pay_index                 in       number   default 0,
                      p_disc_amount               in       number   default null,
                      p_disctype_no               in       number   default null,  
                      p_disc_auth_by              in       number   default null,
                      p_disc_remarks              in       varchar2 default null,
                      p_driver_no                 in       number,
                      p_ambulance_no              in       number,
                      p_from_loc_no               in       number,
                      p_from_location             in       varchar2,
                      p_to_loc_no                 in       number,
                      p_to_location               in       varchar2,
                      p_ss_creator                in       number,
                      p_og_no                     in       number,
                      p_company_no                in       number,
                      p_ss_created_session        in       number,
                      p_invoice_no                out      number,
                      p_invoice_id                out      varchar2,
                      p_error                     out      varchar2
                     )
as

    cursor c_config
    is
    select hn_prifix, amb_invoice_prifix opd_invoice_prifix, invoince_method
    from opd_config
    where company_no = p_company_no;
    r_c_config  c_config%rowtype;
    
    v_reg_no            number;
    v_hospital_number   varchar2(50);
    v_bill_index        number := 1;
    v_pay_index         number := 1;
    v_invoicedtl_no     number;
    v_lab_exist         number := 0;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    v_paydtl_no         number;
    
    i_invoicedtl_no         k_ledger.arlist_numb;
    i_item_no               k_ledger.arlist_numb;
    i_item_name             k_ledger.arlist_varc;
    i_item_qty              k_ledger.arlist_numb;
    i_item_rate             k_ledger.arlist_numb;
    i_item_vat              k_ledger.arlist_numb;
    i_urgent_fee            k_ledger.arlist_numb;
    i_service_charge        k_ledger.arlist_numb;
    i_itemtype_no           k_ledger.arlist_numb;
    i_par_itemtype_no       k_ledger.arlist_numb;
    i_bu_no                 k_ledger.arlist_numb;
    i_delivery_status_no    k_ledger.arlist_numb;
    i_package_item_flag     k_ledger.arlist_numb;
    i_pur_rate              k_ledger.arlist_numb;  
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
    v_from_loc_no number;
    v_to_loc_no number;
    
begin
    
    open c_config;
    fetch c_config into r_c_config;
    close c_config;
    
    if p_reg_no is null then
    
        k_general.pd_genarate_id (r_c_config.hn_prifix, 'OPD_REGISTRATION', 'HOSPITAL_NUMBER', p_company_no, v_hospital_number);
        k_general.pd_genarate_no ('SEQ_REG_NO', p_company_no, v_reg_no, 'YY', 10);
        
        insert into opd_registration (reg_no, hospital_number, reg_date, salutation, 
                                      fname, lname, gender, m_status, 
                                      age_dd, age_mm, age_yy, dob, 
                                      blood_group, religion, phone_mobile, email, 
                                      address, national_id, pat_type_no, reg_point, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
                                      
        values (v_reg_no, v_hospital_number, sysdate, p_salutation, 
                p_fname, p_lname, p_gender, p_m_status, 
                p_age_dd, p_age_mm, p_age_yy, p_dob, 
                p_blood_group, p_religion, p_phone_mobile, p_email, 
                p_address, p_national_id, p_pat_type_no, 5, p_ss_creator, 
                sysdate, p_ss_created_session, p_company_no);
    
    else
        v_reg_no := p_reg_no;        
    end if;
    
    k_general.pd_genarate_no ('SEQ_INVOICE_NO', p_company_no, p_invoice_no,'YY', 10);
    
    if r_c_config.invoince_method is null then
        
        k_general.pd_genarate_id (r_c_config.opd_invoice_prifix, 'OPD_INVOICE', 'OPD_INVOICE_ID', p_company_no, p_invoice_id);
            
    else    
        
        execute immediate 'SELECT '||r_c_config.invoince_method|| ' FROM SYS.DUAL' into p_invoice_id;
            
    end if;
    
    insert into opd_invoice (opd_invoice_no, opd_invoice_id, bill_module_no, reg_no, 
                              admission_no, admission_id, consultation_no, invoice_date, 
                              invoice_datetime, doctor_no, remarks, 
                              cor_client_no,  cor_client_card_no, emp_no, relation_no, 
                              pat_type_no, ss_creator, ss_created_on, 
                              ss_created_session, company_no)
    values (p_invoice_no, p_invoice_id, 12, v_reg_no,
            p_admission_no, p_admission_id, p_consultation_no, trunc(sysdate),
            sysdate, p_ref_doc_no, p_remarks,
            p_cor_client_no, p_cor_client_emp_id, p_emp_no, p_relation_no, 
            p_pat_type_no, p_ss_creator, sysdate, 
            p_ss_created_session, p_company_no);
    
    
    if p_from_loc_no is null then
        
        v_from_loc_no := fd_auto_no('SA_LOCATION_SETUP','LOCATION_NO',p_company_no);
        
        insert into sa_location_setup (location_no, location_id, location_name, active_stat, 
                                       ss_creator, ss_created_on, ss_created_session, company_no)
        values (v_from_loc_no, v_from_loc_no, p_from_location, 1,
                p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
    else
        
        v_from_loc_no := p_from_loc_no;
        
    end if;
    
    if p_to_loc_no is null then
        
        v_to_loc_no := fd_auto_no('SA_LOCATION_SETUP','LOCATION_NO',p_company_no);
        
        insert into sa_location_setup (location_no, location_id, location_name, active_stat, 
                                       ss_creator, ss_created_on, ss_created_session, company_no)
        values (v_to_loc_no, v_to_loc_no, p_to_location, 1,
                p_ss_creator, sysdate, p_ss_created_session, p_company_no);
                
    else
        
        v_to_loc_no := p_to_loc_no;
        
    end if;
    
    
    insert into opd_invoice_ambulance (opd_invoice_no, driver_no, ambulance_no, from_location_no, 
                                       to_location_no, start_time, ss_creator, ss_created_on, 
                                       ss_created_session, company_no)
    values (p_invoice_no, p_driver_no, p_ambulance_no, v_from_loc_no, 
            v_to_loc_no, sysdate, p_ss_creator, sysdate, 
            p_ss_created_session, p_company_no);
    
    loop
    
        k_general.pd_genarate_no ('SEQ_INVOICEDTL_NO', p_company_no, v_invoicedtl_no,'YY',10);
          
        insert into opd_invoicedtl(opd_invoicedtl_no, opd_invoice_no, item_no, item_name, 
                                    itemtype_no, item_qty, item_rate, item_vat, 
                                    urgent_fee, service_charge, package_item_flag, bu_no, 
                                    ss_creator, ss_created_on, ss_created_session, company_no)
        values(v_invoicedtl_no, p_invoice_no, p_item_no (v_bill_index), p_item_name (v_bill_index), 
               p_itemtype_no (v_bill_index), p_item_qty (v_bill_index), p_item_rate (v_bill_index), p_item_vat (v_bill_index), 
               p_urgent_fee (v_bill_index), p_service_charge (v_bill_index), p_package_item_flag (v_bill_index), p_bu_no (v_bill_index), 
               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        i_invoicedtl_no (v_bill_index) := v_invoicedtl_no;
        i_item_no            (v_bill_index) := p_item_no (v_bill_index);
        i_item_name          (v_bill_index) := p_item_name (v_bill_index);
        i_item_qty           (v_bill_index) := p_item_qty (v_bill_index);
        i_item_rate          (v_bill_index) := p_item_rate (v_bill_index);
        i_item_vat           (v_bill_index) := p_item_vat (v_bill_index);
        i_urgent_fee         (v_bill_index) := p_urgent_fee (v_bill_index);
        i_service_charge     (v_bill_index) := p_service_charge (v_bill_index);
        i_itemtype_no        (v_bill_index) := p_itemtype_no (v_bill_index);
        i_par_itemtype_no    (v_bill_index) := p_par_itemtype_no (v_bill_index);
        i_bu_no              (v_bill_index) := p_bu_no (v_bill_index);
        i_delivery_status_no (v_bill_index) := p_delivery_status_no (v_bill_index);
        i_package_item_flag  (v_bill_index) := p_package_item_flag (v_bill_index);
        i_pur_rate           (v_bill_index) := null;
                                           
    exit when v_bill_index >= nvl (p_item_index, 0);
        v_bill_index := v_bill_index + 1; 
    end loop;
    
                                  
    k_ledger.pd_ledger_bill(p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => 12,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_ref_doc_no                => p_ref_doc_no,
                            p_second_ref_doc_no         => null, 
                            p_invoicedtl_no             => i_invoicedtl_no,                    
                            p_item_no                   => i_item_no,
                            p_item_name                 => i_item_name,
                            p_item_qty                  => i_item_qty,
                            p_item_rate                 => i_item_rate,
                            p_item_vat                  => i_item_vat,
                            p_urgent_fee                => i_urgent_fee,
                            p_service_charge            => i_service_charge,
                            p_itemtype_no               => i_itemtype_no,
                            p_par_itemtype_no           => i_par_itemtype_no,
                            p_bu_no                     => i_bu_no,
                            p_delivery_status_no        => i_delivery_status_no,
                            p_package_item_flag         => i_package_item_flag,
                            p_pur_rate                  => i_pur_rate,
                            p_inv_index                 => v_bill_index,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
                      
    v_bill_index := 1;
    
    if nvl(p_disc_amount,0) > 0 then
        
        k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
        k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);            
  
        insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                  reg_no, invoice_no, admission_no, disc_type_no, pay_amt,
                                  pay_type_no, disc_auth_by, disc_remarks, ss_creator, 
                                  ss_created_on, ss_created_session, company_no)
        values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 12,
               v_reg_no, p_invoice_no, p_admission_no, p_disctype_no, p_disc_amount,
               6, p_disc_auth_by, p_disc_remarks, p_ss_creator, 
               sysdate, p_ss_created_session, p_company_no);    
        
        loop
        
            k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY',10);    
        
            insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                         reg_no, invoice_no, invoicedtl_no, admission_no, 
                                         item_no, bill_module_no, disc_type_no, cli_disc_amt, 
                                         ss_creator, ss_created_on, ss_created_session, company_no)
            values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                   v_reg_no, p_invoice_no, i_invoicedtl_no (v_bill_index), p_admission_no,
                   p_item_no (v_bill_index), 12, p_disctype_no, p_cli_disc_amt (v_bill_index),
                   p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        exit when v_bill_index >= nvl (p_item_index, 0);
            v_bill_index := v_bill_index + 1; 
        end loop;
        
        i_pay_no        (1) := v_pay_no;
        i_pay_mode      (1) := null;
        i_coll_mode     (1) := null;
        i_pay_type_no   (1) := 6;
        i_amount        (1) := p_disc_amount;
        i_given_amt     (1) := null;
        
        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => 12,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => 1,
                            p_disctype_no               => p_disctype_no,  
                            p_disc_auth_by              => p_disc_auth_by,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
        
    end if;
      
    if nvl(p_pay_index,0) > 0 then
    
        loop
        
            k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
            k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);
            
            insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                      reg_no, invoice_no, admission_no, pay_amt, 
                                      pay_type_no, pay_mode, coll_mode, pay_cqcc_others, 
                                      pay_bank_name, given_amt, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
            values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, 12,
                   v_reg_no, p_invoice_no, p_admission_no, p_pay_amt (v_pay_index), 
                   p_pay_type_no (v_pay_index), p_pay_mode (v_pay_index), p_coll_mode (v_pay_index), p_pay_cqcc_others (v_pay_index), 
                   p_pay_bank_name (v_pay_index), p_given_amt (v_pay_index), p_ss_creator, 
                   sysdate, p_ss_created_session, p_company_no);
        
            i_pay_no        (v_pay_index) := v_pay_no;
            i_pay_mode      (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode     (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no   (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount        (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt     (v_pay_index) := p_given_amt (v_pay_index);
                
        exit when v_pay_index >= nvl (p_pay_index, 0);
            v_pay_index := v_pay_index + 1; 
        end loop;

        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => 12,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_pay_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
                    
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_ambulance_invoice;

procedure pd_payment (
                      p_invoice_no          in number,
                      p_invoice_id          in varchar2,
                      p_reg_no              in number,
                      p_admission_no        in number   default null,
                      p_admission_id        in varchar2 default null,
                      p_bed_no              in number   default null,
                      p_consultation_no     in number   default null,
                      p_bill_module_no      in number,
                      p_pay_mode            in k_opd.arlist_numb,
                      p_coll_mode           in k_opd.arlist_numb,
                      p_pay_type_no         in k_opd.arlist_numb,
                      p_pay_cqcc_others     in k_opd.arlist_varc,
                      p_pay_bank_name       in k_opd.arlist_varc,
                      p_pay_amt             in k_opd.arlist_numb,
                      p_given_amt           in k_opd.arlist_numb,
                      p_pay_index           in number,
                      p_pay_remarks         in varchar2,
                      p_ss_creator          in number,
                      p_og_no               in number,
                      p_company_no          in number,
                      p_ss_created_session  in number,
                      p_error               out varchar2
                     )
is
    
    v_pay_index         number := 1;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
begin
    
    if nvl(p_pay_index,0) > 0 then
    
        loop
        
            k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
            k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);
            
            insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                      reg_no, invoice_no, admission_no, pay_amt, 
                                      pay_type_no, pay_mode, coll_mode, pay_cqcc_others, 
                                      pay_bank_name, given_amt, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
            values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
                   p_reg_no, p_invoice_no, p_admission_no, p_pay_amt (v_pay_index), 
                   p_pay_type_no (v_pay_index), p_pay_mode (v_pay_index), p_coll_mode (v_pay_index), p_pay_cqcc_others (v_pay_index), 
                   p_pay_bank_name (v_pay_index), p_given_amt (v_pay_index), p_ss_creator, 
                   sysdate, p_ss_created_session, p_company_no);
        
            i_pay_no        (v_pay_index) := v_pay_no;
            i_pay_mode      (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode     (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no   (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount        (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt     (v_pay_index) := p_given_amt (v_pay_index);
                
        exit when v_pay_index >= nvl (p_pay_index, 0);
            v_pay_index := v_pay_index + 1; 
        end loop;

        k_ledger.pd_ledger (p_reg_no                    => p_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_pay_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
                    
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_payment;

procedure pd_discount (
                      p_invoice_no          in number,
                      p_invoice_id          in varchar2,
                      p_reg_no              in number,
                      p_admission_no        in number   default null,
                      p_admission_id        in varchar2 default null,
                      p_bed_no              in number   default null,
                      p_consultation_no     in number   default null,
                      p_disc_amount         in number,
                      p_disctype_no         in number,
                      p_disc_auth_by        in number default null,
                      p_disc_remarks        in varchar2 default null,
                      p_bill_module_no      in number,
                      p_invoicedtl_no       in k_opd.arlist_numb,
                      p_item_no             in k_opd.arlist_numb,                     
                      p_cli_disc_amt        in k_opd.arlist_numb,
                      p_ref_disc_amt        in k_opd.arlist_numb,
                      p_index               in number,
                      p_ss_creator          in number,
                      p_og_no               in number,
                      p_company_no          in number,
                      p_ss_created_session  in number,
                      p_error               out varchar2
                     )
is
    
    v_bill_index        number := 1;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    v_paydtl_no         number;
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
begin
    
    if nvl(p_disc_amount,0) > 0 then
        
        k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
        k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);            
  
        insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                  reg_no, invoice_no, admission_no, disc_type_no, pay_amt,
                                  pay_type_no, disc_auth_by, disc_remarks, ss_creator, 
                                  ss_created_on, ss_created_session, company_no)
        values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
               p_reg_no, p_invoice_no, p_admission_no, p_disctype_no, p_disc_amount,
               7, p_disc_auth_by, p_disc_remarks, p_ss_creator, 
               sysdate, p_ss_created_session, p_company_no);    
        
        loop
        
            k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY',10);    
        
            insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                         reg_no, invoice_no, invoicedtl_no, admission_no, 
                                         item_no, bill_module_no, disc_type_no, cli_disc_amt, ref_disc_amt, 
                                         ss_creator, ss_created_on, ss_created_session, company_no)
            values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                   p_reg_no, p_invoice_no, p_invoicedtl_no (v_bill_index), p_admission_no,
                   p_item_no (v_bill_index), p_bill_module_no, p_disctype_no, p_cli_disc_amt (v_bill_index), p_ref_disc_amt (v_bill_index), 
                   p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        exit when v_bill_index >= nvl (p_index, 0);
            v_bill_index := v_bill_index + 1; 
        end loop;
        
        i_pay_no        (1) := v_pay_no;
        i_pay_mode      (1) := null;
        i_coll_mode     (1) := null;
        i_pay_type_no   (1) := 7;
        i_amount        (1) := p_disc_amount;
        i_given_amt     (1) := null;
        
        k_ledger.pd_ledger (p_reg_no                    => p_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => 1,
                            p_disctype_no               => p_disctype_no,  
                            p_disc_auth_by              => p_disc_auth_by,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
        
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_discount;

procedure pd_due_coll_disc_ref (
                          p_invoice_no          in number,
                          p_bill_module_no      in number,
                          p_pay_mode            in k_opd.arlist_numb,
                          p_coll_mode           in k_opd.arlist_numb,
                          p_pay_type_no         in k_opd.arlist_numb,
                          p_pay_cqcc_others     in k_opd.arlist_varc,
                          p_pay_bank_name       in k_opd.arlist_varc,
                          p_pay_amt             in k_opd.arlist_numb,
                          p_given_amt           in k_opd.arlist_numb,
                          p_pay_index           in number,
                          p_pay_remarks         in varchar2,
                          p_refund_amount       in number,
                          p_refund_remarks      in varchar2,
                          p_disc_amount         in number,
                          p_disctype_no         in number,
                          p_disc_auth_by        in number default null,
                          p_invoicedtl_no       in k_opd.arlist_numb,
                          p_item_no             in k_opd.arlist_numb,                     
                          p_cli_disc_amt        in k_opd.arlist_numb,
                          p_ref_disc_amt        in k_opd.arlist_numb,
                          p_disc_index          in number,
                          p_disc_remarks        in varchar2 default null,
                          p_cor_client_no       in number default null,
                          p_cor_client_emp_id   in varchar2 default null,
                          p_emp_no              in number default null,
                          p_relation_no         in number default null,
                          p_ss_creator          in number,
                          p_og_no               in number,
                          p_company_no          in number,
                          p_ss_created_session  in number,
                          p_error               out varchar2
                         )
is
    
    v_index               number := 0;
    
    i_pay_mode            k_opd.arlist_numb;
    i_coll_mode           k_opd.arlist_numb;
    i_pay_type_no         k_opd.arlist_numb;
    i_pay_cqcc_others     k_opd.arlist_varc;
    i_pay_bank_name       k_opd.arlist_varc;
    i_pay_amt             k_opd.arlist_numb;
    i_given_amt           k_opd.arlist_numb;
    
    cursor c_bill_info
    is
    select opd_invoice_id invoice_id, reg_no, admission_no, admission_id, consultation_no,
           case when admission_no is not null then k_ipd.fd_current_bed_no(admission_no) else null end bed_no
    from opd_invoice
    where opd_invoice_no = p_invoice_no;
    r_c_bill_info c_bill_info%rowtype;
    
    i_invoicedtl_no       k_opd.arlist_numb;
    i_item_no             k_opd.arlist_numb;                    
    i_cli_disc_amt        k_opd.arlist_numb;
    i_ref_disc_amt        k_opd.arlist_numb;
                                                    
begin
    
    open c_bill_info;
    fetch c_bill_info into r_c_bill_info;
    close c_bill_info;    
    
    if p_pay_index > 0 then
        
        for i in 1..p_pay_index loop
            
            v_index := v_index + 1;
            
            i_pay_mode            (v_index) := p_pay_mode (v_index);
            i_coll_mode           (v_index) := p_coll_mode (v_index);
            i_pay_type_no         (v_index) := p_pay_type_no (v_index);
            i_pay_cqcc_others     (v_index) := p_pay_cqcc_others (v_index);
            i_pay_bank_name       (v_index) := p_pay_bank_name (v_index);
            i_pay_amt             (v_index) := p_pay_amt (v_index);
            i_given_amt           (v_index) := p_given_amt (v_index);
        
        end loop;
            
        pd_payment (
                  p_invoice_no          => p_invoice_no,
                  p_invoice_id          => r_c_bill_info.invoice_id,
                  p_reg_no              => r_c_bill_info.reg_no,
                  p_admission_no        => r_c_bill_info.admission_no,
                  p_admission_id        => r_c_bill_info.admission_id,
                  p_bed_no              => r_c_bill_info.bed_no,
                  p_consultation_no     => r_c_bill_info.consultation_no,
                  p_bill_module_no      => p_bill_module_no,
                  p_pay_mode            => i_pay_mode,
                  p_coll_mode           => i_coll_mode,
                  p_pay_type_no         => i_pay_type_no,
                  p_pay_cqcc_others     => i_pay_cqcc_others,
                  p_pay_bank_name       => i_pay_bank_name,
                  p_pay_amt             => i_pay_amt,
                  p_given_amt           => i_given_amt,
                  p_pay_index           => v_index,
                  p_pay_remarks         => p_pay_remarks,
                  p_ss_creator          => p_ss_creator,
                  p_og_no               => p_og_no,
                  p_company_no          => p_company_no,
                  p_ss_created_session  => p_ss_created_session,
                  p_error               => p_error
                 );
                 
    end if;
    
    if nvl(p_refund_amount,0) > 0 then
        
        v_index := 1;
            
        i_pay_mode            (v_index) := 1;
        i_coll_mode           (v_index) := null;
        i_pay_type_no         (v_index) := 5;
        i_pay_cqcc_others     (v_index) := null;
        i_pay_bank_name       (v_index) := null;
        i_pay_amt             (v_index) := p_refund_amount;
        i_given_amt           (v_index) := null;
        
        pd_refund (
                  p_invoice_no          => p_invoice_no,
                  p_invoice_id          => r_c_bill_info.invoice_id,
                  p_reg_no              => r_c_bill_info.reg_no,
                  p_admission_no        => r_c_bill_info.admission_no,
                  p_admission_id        => r_c_bill_info.admission_id,
                  p_bed_no              => r_c_bill_info.bed_no,
                  p_consultation_no     => r_c_bill_info.consultation_no,
                  p_bill_module_no      => p_bill_module_no,
                  p_pay_mode            => i_pay_mode,
                  p_coll_mode           => i_coll_mode,
                  p_pay_type_no         => i_pay_type_no,
                  p_pay_cqcc_others     => i_pay_cqcc_others,
                  p_pay_bank_name       => i_pay_bank_name,
                  p_pay_amt             => i_pay_amt,
                  p_given_amt           => i_given_amt,
                  p_pay_index           => v_index,
                  p_pay_remarks         => p_refund_remarks,
                  p_ss_creator          => p_ss_creator,
                  p_og_no               => p_og_no,
                  p_company_no          => p_company_no,
                  p_ss_created_session  => p_ss_created_session,
                  p_error               => p_error             
                  );
                  
    end if;    
    
    if nvl(p_disc_amount,0) > 0 then
        
        v_index := 0;
        
        for i in 1..p_disc_index loop
            
            v_index := v_index + 1;
            
            i_invoicedtl_no       (v_index) := p_invoicedtl_no (v_index);
            i_item_no             (v_index) := p_item_no (v_index);                    
            i_cli_disc_amt        (v_index) := p_cli_disc_amt (v_index);
            i_ref_disc_amt        (v_index) := p_ref_disc_amt (v_index);
        
        end loop;
        
        pd_discount (
                      p_invoice_no          => p_invoice_no,
                      p_invoice_id          => r_c_bill_info.invoice_id,
                      p_reg_no              => r_c_bill_info.reg_no,
                      p_admission_no        => r_c_bill_info.admission_no,
                      p_admission_id        => r_c_bill_info.admission_id,
                      p_bed_no              => r_c_bill_info.bed_no,
                      p_consultation_no     => r_c_bill_info.consultation_no,
                      p_disc_amount         => p_disc_amount,
                      p_disctype_no         => p_disctype_no,
                      p_disc_auth_by        => p_disc_auth_by,
                      p_disc_remarks        => p_disc_remarks,
                      p_bill_module_no      => p_bill_module_no,
                      p_invoicedtl_no       => i_invoicedtl_no,
                      p_item_no             => i_item_no,                     
                      p_cli_disc_amt        => i_cli_disc_amt,
                      p_ref_disc_amt        => i_ref_disc_amt,
                      p_index               => v_index,
                      p_ss_creator          => p_ss_creator,
                      p_og_no               => p_og_no,
                      p_company_no          => p_company_no,
                      p_ss_created_session  => p_ss_created_session,
                      p_error               => p_error 
                      );   
        
    end if;
    
    update opd_invoice
    set cor_client_no       = nvl(cor_client_no, p_cor_client_no), 
        cor_client_card_no  = nvl(cor_client_card_no, p_cor_client_emp_id), 
        emp_no              = nvl(emp_no, p_emp_no), 
        relation_no         = nvl(relation_no, p_relation_no), 
        ss_modifier         = p_ss_creator, 
        ss_modified_on      = sysdate, 
        ss_modified_session = p_ss_created_session
    where opd_invoice_no = p_invoice_no;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then 
    p_error := sqlerrm;
end pd_due_coll_disc_ref; 


procedure pd_invoice_doctor_change (
                                  p_invoice_no             in number,
                                  p_consultation_no        in number,                                  
                                  p_doctor_no_old          in number,
                                  p_doctor_no_new          in number,
                                  p_doc_change_reason      in varchar2,
                                  p_bu_no_old              in number,
                                  p_bu_no_new              in number,
                                  p_ss_creator             in number,
                                  p_og_no                  in number,
                                  p_company_no             in number,
                                  p_ss_created_session     in number,
                                  p_error                  out varchar2
                                  )
is
    v_doc_log_no number;
    
begin
    
    if p_doctor_no_new is not null then
        
        update opd_invoice
        set doctor_no = p_doctor_no_new, 
            ss_modifier = p_ss_creator, 
            ss_modified_on = sysdate,
            ss_modified_session = p_ss_created_session        
        where opd_invoice_no = p_invoice_no;
        
        update opd_consultation
        set doctor_no = p_doctor_no_new,
            ref_doctor_no = p_doctor_no_new,
            bu_no = p_bu_no_new, 
            ss_modifier = p_ss_creator, 
            ss_modified_on = sysdate,
            ss_modified_session = p_ss_created_session        
        where opd_consultation_no = p_consultation_no;
        
        update opd_appointment
        set doctor_no = p_doctor_no_new,
            bu_no = p_bu_no_new,
            ss_modifier = p_ss_creator, 
            ss_modified_on = sysdate,
            ss_modified_session = p_ss_created_session        
        where appoint_no in ( select appointment_no 
                               from opd_consultation 
                               where opd_consultation_no = p_consultation_no);
        
        k_general.pd_genarate_no ('SEQ_DOC_LOG_NO', p_company_no, v_doc_log_no,'YY',10);

        insert into OPD_INVOICEDOCTOR_LOG (doc_log_no, invoice_no, old_doctor_no, new_doctor_no, 
                                            old_bu_no,new_bu_no,
                                            changed_by, changed_timestamp, changed_reason, ss_creator, 
                                            ss_created_on, ss_created_session, company_no)
        values (v_doc_log_no, p_invoice_no, p_doctor_no_old, p_doctor_no_new, 
                p_bu_no_old,p_bu_no_new,
                p_ss_creator, sysdate, p_doc_change_reason, p_ss_creator,
                sysdate, p_ss_created_session, p_company_no);
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then 
    p_error := sqlerrm;
end pd_invoice_doctor_change;


   PROCEDURE pd_gen_app_slot_web (
      p_doc_no               IN       NUMBER,
      p_app_date             IN       DATE,
      p_shift_no             IN       NUMBER,
      p_ss_creator           IN       NUMBER,
      p_og_no                IN       NUMBER,
      p_company_no           IN       NUMBER,
      p_ss_created_session   IN       NUMBER,
      p_error                OUT      VARCHAR
   )
   /*
   business logic imported from k_opd.pd_gen_app_slot
   removed 3 parameter
   created by: aftab
   date: 19-Jun-2019
   
   Modified By Md Masud Billah.
   Modified On : 13.06.2021
   Purpose : add c_avg_load cursor and removed loop to assign avg_load_per_day value. 
   */
   AS
      v_time_diff          NUMBER;
      v_avg_slot_dur       NUMBER;
      v_remain_time        NUMBER;
      v_slot_dur           NUMBER;
      v_start_min          NUMBER;
      v_slot_no            NUMBER;
      v_gen_slot_no        NUMBER;
      v_stdt               DATE;
      v_endt               DATE;
      
      
cursor c_avg_load
    is
select t.start_time, t.end_time, t.avg_load_per_day
  from hpms_con_doc_sch_v t
 where t.doctor_no = p_doc_no
   and t.shift_no = p_shift_no
   and t.empschedule_dt = p_app_date;
   
   v_c_avg_load   c_avg_load%rowtype;
      
      
   BEGIN

        OPEN c_avg_load;  FETCH c_avg_load INTO v_c_avg_load; CLOSE c_avg_load;      
        
         v_stdt := to_date ((to_char (p_app_date, 'DD/MM/YYYY ') || to_char (v_c_avg_load.start_time, 'HH24:MI') ), 'DD/MM/YYYY HH24:MI' );
         v_endt := to_date ((to_char (p_app_date, 'DD/MM/YYYY ') || to_char (v_c_avg_load.end_time, 'HH24:MI') ), 'DD/MM/YYYY HH24:MI' );


      if v_c_avg_load.start_time is not null and v_c_avg_load.end_time is not null
      then
         v_time_diff :=
              (  to_number (to_char (v_endt, 'hh24')) * 60 + TO_NUMBER (TO_CHAR (v_endt, 'mi')) )
            - (  TO_NUMBER (TO_CHAR (v_stdt, 'hh24')) * 60 + TO_NUMBER (TO_CHAR (v_stdt, 'mi')) );
         v_avg_slot_dur := FLOOR (v_time_diff / NVL (v_c_avg_load.avg_load_per_day, 1));
         v_remain_time := MOD (v_time_diff, NVL (v_c_avg_load.avg_load_per_day, 1));

         FOR i IN 1 .. NVL (v_c_avg_load.avg_load_per_day, 1)
         LOOP
            IF i = v_c_avg_load.avg_load_per_day
            THEN
               v_slot_dur := v_avg_slot_dur - 1 + v_remain_time;
            ELSIF i - 1 > 0
            THEN
               v_slot_dur := v_avg_slot_dur - 1;
            ELSE
               v_slot_dur := v_avg_slot_dur;
            END IF;

            IF i - 1 > 0
            THEN
               v_start_min := (v_avg_slot_dur * (i - 1)) + 1;
            ELSE
               v_start_min := 0;
            END IF;

            pd_ins_app_slot
                      (p_doc_no                  => p_doc_no,
                       p_app_date                => p_app_date,
                       p_shift_no                => p_shift_no,
                       p_start_time              => k_general.fd_add_daytime
                                                                 (v_stdt,
                                                                  0,
                                                                  0,
                                                                  v_start_min,
                                                                  0
                                                                 ),
                       p_end_time                => k_general.fd_add_daytime
                                                                 (v_stdt,
                                                                  0,
                                                                  0,
                                                                  v_start_min,
                                                                  0
                                                                 ),
                       p_duration                => v_slot_dur,
                       p_extra_slot              => 0,
                       p_slot_sl                 => v_slot_no,
                       p_ss_creator              => p_ss_creator,
                       p_og_no                   => p_og_no,
                       p_company_no              => p_company_no,
                       p_ss_created_session      => p_ss_created_session,
                       p_slot_no                 => v_gen_slot_no,
                       p_error                   => p_error
                      );
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
   END pd_gen_app_slot_web;

   PROCEDURE pd_doctor_serial_reset_web (
      p_doctor_no    IN       NUMBER,
      p_app_date     IN       DATE,
      p_shift_no     IN       NUMBER,
      p_val          OUT      NUMBER,
      p_slot_no      OUT      NUMBER,
      p_start_time   OUT      DATE,
      p_end_time     OUT      DATE
   )
   IS
      CURSOR c_app
      IS
         SELECT t.slot_no, t.slot_sl, t.start_time, t.end_time
           FROM (SELECT   s.slot_no, s.slot_sl, s.start_time, s.end_time
                     FROM opd_appointment_slot s
                    WHERE s.doctor_no = p_doctor_no
                      AND s.slot_date = p_app_date
                      AND s.shiftdtl_no = p_shift_no -------------------------------
                      AND s.slot_no NOT IN (SELECT o.slot_no
                                              FROM opd_appointment o)
                      AND s.start_time > SYSDATE
                 ORDER BY s.slot_sl) t
          WHERE ROWNUM <= 1;

      v_slot_sl   NUMBER;

      CURSOR c_sch
      IS
         SELECT        NVL (sl, 0) sl
                  FROM hpms_doc_app_sl
                 WHERE doctor_no = p_doctor_no
                   AND app_date = p_app_date
                   AND shiftdtl_no = p_shift_no
         FOR UPDATE OF sl WAIT 60;

      v_sl        NUMBER;
      v_error     VARCHAR2 (1000);
   BEGIN
      OPEN c_sch;

      FETCH c_sch
       INTO v_sl;

      IF c_sch%NOTFOUND
      THEN
         OPEN c_app;

         FETCH c_app
          INTO p_slot_no, v_slot_sl, p_start_time, p_end_time;

         IF c_app%NOTFOUND OR v_slot_sl = 0
         THEN
            INSERT INTO hpms_doc_app_sl
                        (doctor_no, app_date, shiftdtl_no, sl
                        )
                 VALUES (p_doctor_no, p_app_date, p_shift_no, 1
                        );

            p_val := 1;
            COMMIT;
         ELSE
            INSERT INTO hpms_doc_app_sl
                        (doctor_no, app_date, shiftdtl_no, sl
                        )
                 VALUES (p_doctor_no, p_app_date, p_shift_no, v_slot_sl
                        );

            p_val := v_slot_sl;
            COMMIT;
         END IF;

         CLOSE c_app;
      ELSE
         UPDATE hpms_doc_app_sl
            SET sl = v_sl + 1
          WHERE doctor_no = p_doctor_no
            AND app_date = p_app_date
            AND shiftdtl_no = p_shift_no;

         p_val := v_sl + 1;
         COMMIT;
      END IF;

      CLOSE c_sch;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
   END pd_doctor_serial_reset_web;
   

PROCEDURE pd_cosnultation_bill_web (
      p_doctor_no              IN       NUMBER,
      p_duration               IN       NUMBER,
      p_appoint_no             IN OUT   NUMBER,
      p_appoint_date           IN       DATE,
      p_shiftdtl_no            IN       NUMBER,
      p_reg_no                 IN       NUMBER,
      p_hospital_number        IN       VARCHAR2 DEFAULT NULL,
      p_patient_type_no        IN       NUMBER,
      p_ref_doc_no             IN       NUMBER DEFAULT NULL,
      p_salutation             IN       VARCHAR2,
      p_patient_name           IN       VARCHAR2,
      p_phone_mobile           IN       VARCHAR2,
      p_email                  IN       VARCHAR2,
      p_dob                    IN       DATE,
      p_age_dd                 IN       NUMBER,
      p_age_mm                 IN       NUMBER,
      p_age_yy                 IN       NUMBER,
      p_gender                 IN       VARCHAR2,
      p_m_status               IN       VARCHAR2,
      p_blood_group            IN       VARCHAR2,
      p_address                IN       VARCHAR2,
      p_bu_no                  IN       NUMBER,
      p_consultation_type_no   IN       NUMBER,
      p_appoint_type           IN       VARCHAR2,
      p_appoint_status         IN       NUMBER,
      p_app_from_flag          IN       NUMBER,
      p_chif_complain          IN       VARCHAR2,
      p_consult_fee            IN       NUMBER,
      p_next_followup_date     IN       DATE,
      p_pres_admission_date    IN       DATE,
      p_cor_client_no          IN       NUMBER DEFAULT NULL,
      p_cor_client_emp_id      IN       VARCHAR2 DEFAULT NULL,
      p_emp_no                 IN       NUMBER DEFAULT NULL,
      p_relation_no            IN       NUMBER DEFAULT NULL,
      p_remarks                IN       VARCHAR2 DEFAULT NULL,
      p_salesrep_no            IN       NUMBER DEFAULT NULL,
      p_card_no                IN       NUMBER DEFAULT NULL,
      p_item_no                IN       k_opd.arlist_numb,
      p_item_name              IN       k_opd.arlist_varc,
      p_item_qty               IN       k_opd.arlist_numb,
      p_itemtype_no            IN       k_opd.arlist_numb,
      p_par_itemtype_no        IN       k_opd.arlist_numb,
      p_item_rate              IN       k_opd.arlist_numb,
      p_item_vat               IN       k_opd.arlist_numb,
      p_urgent_fee             IN       k_opd.arlist_numb,
      p_service_charge         IN       k_opd.arlist_numb,
      p_delivery_status_no     IN       k_opd.arlist_numb,
      p_package_item_flag      IN       k_opd.arlist_numb,
      p_cli_disc_amt           IN       k_opd.arlist_numb,
      p_item_index             IN       NUMBER,
      p_pay_mode               IN       k_opd.arlist_numb,
      p_coll_mode              IN       k_opd.arlist_numb,
      p_pay_type_no            IN       k_opd.arlist_numb,
      p_pay_cqcc_others        IN       k_opd.arlist_varc,
      p_pay_bank_name          IN       k_opd.arlist_varc,
      p_pay_amt                IN       k_opd.arlist_numb,
      p_given_amt              IN       k_opd.arlist_numb,
      p_pay_index              IN       NUMBER DEFAULT 0,
      p_disc_amount            IN       NUMBER DEFAULT NULL,
      p_disctype_no            IN       NUMBER DEFAULT NULL,
      p_disc_auth_by           IN       NUMBER DEFAULT NULL,
      p_disc_remarks           IN       VARCHAR2 DEFAULT NULL,
      p_ss_creator             IN       NUMBER,
      p_ss_created_session     IN       NUMBER,
      p_og_no                  IN       NUMBER,
      p_company_no             IN       NUMBER,
      p_slot_no                IN OUT   NUMBER,
      p_slot_sl                IN OUT   NUMBER,
      p_start_time             IN OUT   DATE,
      p_end_time               IN OUT   DATE,
      p_consultation_no        OUT      NUMBER,
      p_consultation_id        OUT      VARCHAR2,
      p_invoice_no             OUT      NUMBER,
      p_invoice_id             OUT      VARCHAR2,
      p_error                  OUT      VARCHAR2
   )
   IS
      /*
      CURSOR c_app
      IS
         SELECT MAX (slot_no) slot_no, MAX (start_time) start_time,
                MAX (end_time) end_time
           FROM opd_appointment
          WHERE doctor_no = NVL (p_doctor_no, 26)
            AND appoint_date = p_appoint_date
            AND shiftdtl_no = p_shiftdtl_no;
      
      r_c_app                c_app%ROWTYPE;
      */
      
      CURSOR c_con_type_prfx
      IS
         SELECT consult_type_prifx
           FROM hpms_consulttype
          WHERE consult_type_no = p_consultation_type_no;

      v_appoint_id           VARCHAR2 (50);
      v_consult_type_prifx   VARCHAR2 (10);

      CURSOR c_item
      IS
         SELECT item_no, item_id, item_name, itemtype_no, bu_no, sales_price,
                vat
           FROM in_item
          WHERE itemtype_no = 14 AND bu_no = p_bu_no
                AND NVL (active_stat, 0) = 0;

      r_c_item               c_item%ROWTYPE;

      CURSOR c_config
      IS
         SELECT hn_prifix, opd_invoice_prifix, invoince_method
           FROM opd_config
          WHERE company_no = p_company_no;

      r_c_config             c_config%ROWTYPE;
      v_hospital_number      VARCHAR2 (50);
      v_reg_no               NUMBER;
      v_invoice_no           NUMBER;
      v_invoice_id           VARCHAR2 (50);
      i_item_no              k_opd.arlist_numb;
      i_item_name            k_opd.arlist_varc;
      i_item_qty             k_opd.arlist_numb;
      i_item_rate            k_opd.arlist_numb;
      i_item_vat             k_opd.arlist_numb;
      i_urgent_fee           k_opd.arlist_numb;
      i_service_charge       k_opd.arlist_numb;
      i_itemtype_no          k_opd.arlist_numb;
      i_par_itemtype_no      k_opd.arlist_numb;
      i_bu_no                k_opd.arlist_numb;
      i_delivery_status_no   k_opd.arlist_numb;
      i_package_item_flag    k_opd.arlist_numb;
      i_cli_disc_amt         k_opd.arlist_numb;
      j_pay_mode             k_opd.arlist_numb;
      j_coll_mode            k_opd.arlist_numb;
      j_pay_type_no          k_opd.arlist_numb;
      j_pay_cqcc_others      k_opd.arlist_varc;
      j_pay_bank_name        k_opd.arlist_varc;
      j_pay_amt              k_opd.arlist_numb;
      j_given_amt            k_opd.arlist_numb;
      
    
    cursor cur_appdtl
    is 
    select   s.slot_no, s.slot_sl, s.start_time, s.end_time
    from opd_appointment_slot s
    where s.doctor_no = p_doctor_no
    and s.slot_date = p_appoint_date
    and s.shiftdtl_no = p_shiftdtl_no   
    and s.slot_status = 0
    and s.slot_no = (select min(o.slot_no)
                     from opd_appointment_slot o
                     where o.doctor_no = p_doctor_no
                     and o.slot_date = p_appoint_date
                     and o.shiftdtl_no = p_shiftdtl_no  
                     and o.slot_status = 0
                     and o.start_time > sysdate)
    and s.start_time > sysdate;      
    
    rec_cur_appdtl  cur_appdtl%rowtype;

    cursor cur_max_sl
    is
    select max (slot_sl)
    from opd_appointment_slot
    where doctor_no = p_doctor_no
    and start_time < sysdate
    and trunc (slot_date) = trunc (p_appoint_date)
    and shiftdtl_no = p_shiftdtl_no;
    
   BEGIN
      OPEN c_config;

      FETCH c_config
       INTO r_c_config;

      CLOSE c_config;      

        if p_slot_no is null then
        
            open cur_appdtl;
            fetch cur_appdtl into rec_cur_appdtl;
            
            if cur_appdtl%found then
                close cur_appdtl;

                --p_start_time := rec_cur_appdtl.end_time;
                --p_end_time := rec_cur_appdtl.end_time + .00001 * 69.445 * nvl (p_duration, 1);                        
                            
                update opd_appointment_slot
                set slot_status = 1                
                where slot_no = rec_cur_appdtl.slot_no;
                
                p_slot_no       := rec_cur_appdtl.slot_no;
                p_slot_sl       := rec_cur_appdtl.slot_sl;
                p_start_time    := rec_cur_appdtl.start_time;
                p_end_time      := rec_cur_appdtl.end_time;
                
            else
                close cur_appdtl;
                 
                open cur_max_sl; fetch cur_max_sl into p_slot_sl; --close cur_max_sl;
                if cur_max_sl%found then
                    close cur_max_sl;
                    p_slot_sl := nvl(p_slot_sl,0) + 1;
                else
                    close cur_max_sl;
                    p_slot_sl := 1; 
                end if;
                           
                p_start_time := sysdate;
                p_end_time := sysdate + .00001 * 69.445 * nvl (p_duration, 1);
                
                k_general.pd_genarate_no ('SEQ_SLOT_NO', p_company_no, p_slot_no);
              
                       insert into application_errors(error_code, error_text, error_timestamp)
                       values('***3',p_slot_no||'::::'||p_slot_sl, sysdate);
                       commit;
                                     
                insert into opd_appointment_slot
                       (slot_no, doctor_no, slot_date,
                        shiftdtl_no, start_time, end_time,
                        duration_min, extra_slot, slot_sl, slot_status,
                        ss_creator, ss_created_on, ss_created_session,
                        company_no
                       )
                values (p_slot_no, p_doctor_no, p_appoint_date,
                        p_shiftdtl_no, p_start_time, p_end_time,
                        nvl (p_duration, 1), 0, p_slot_sl, 1,
                        p_ss_creator, sysdate, p_ss_created_session,
                        p_company_no
                       );
                                              
            end if;   
                
        end if;
            
        --end if;

       /* 
        IF p_slot_no IS NULL
         THEN
            OPEN c_app;

            FETCH c_app
             INTO r_c_app;

            IF c_app%FOUND
            THEN
               CLOSE c_app;

               p_start_time := r_c_app.end_time;
               p_end_time :=
                     r_c_app.end_time + .00001 * 69.445 * NVL (p_duration, 1);
            ELSE
               CLOSE c_app;

               p_start_time := SYSDATE;
               p_end_time := SYSDATE + .00001 * 69.445 * NVL (p_duration, 1);
            END IF;

            k_general.pd_genarate_no ('SEQ_SLOT_NO', p_company_no, p_slot_no);

            IF p_slot_no IS NULL
            THEN
               p_error := 'CANNOT GENERATE THE PRIMARY KEY SLOT NO';
            ELSE
               INSERT INTO opd_appointment_slot
                           (slot_no, doctor_no, slot_date,
                            shiftdtl_no, start_time, end_time,
                            duration_min, extra_slot, slot_sl, slot_status,
                            ss_creator, ss_created_on, ss_created_session,
                            company_no
                           )
                    VALUES (p_slot_no, p_doctor_no, p_appoint_date,
                            p_shiftdtl_no, p_start_time, p_end_time,
                            NVL (p_duration, 1), 0, p_slot_sl, 1,
                            p_ss_creator, SYSDATE, p_ss_created_session,
                            p_company_no
                           );
                           
                           insert into application_errors(ERROR_CODE, ERROR_TEXT, ERROR_TIMESTAMP)
                           values('***3',p_slot_no, sysdate);
                           commit;
                           
            END IF;
         END IF;
      --END IF;
      */
      
      IF p_reg_no IS NULL
      THEN
         k_general.pd_genarate_id (r_c_config.hn_prifix,
                                   'OPD_REGISTRATION',
                                   'HOSPITAL_NUMBER',
                                   p_company_no,
                                   v_hospital_number
                                  );
         k_general.pd_genarate_no ('SEQ_REG_NO',
                                   p_company_no,
                                   v_reg_no,
                                   'YY',
                                   10
                                  );

         IF v_reg_no IS NULL OR v_hospital_number IS NULL
         THEN
            p_error := 'CANNOT GENERATE THE PRIMARY KEY REG NO';
         ELSE
            INSERT INTO opd_registration
                        (reg_no, hospital_number, reg_date, salutation,
                         fname, lname, gender, m_status,
                         age_dd, age_mm, age_yy, dob, blood_group,
                         religion, phone_mobile, email, address,
                         national_id, pat_type_no, reg_point, ss_creator,
                         ss_created_on, ss_created_session, company_no
                        )
                 VALUES (v_reg_no, v_hospital_number, SYSDATE, p_salutation,
                         p_patient_name, NULL, p_gender, p_m_status,
                         p_age_dd, p_age_mm, p_age_yy, p_dob, p_blood_group,
                         NULL, p_phone_mobile, p_email, p_address,
                         NULL, p_patient_type_no, 1, p_ss_creator,
                         SYSDATE, p_ss_created_session, p_company_no
                        );
         END IF;
      ELSE
         UPDATE opd_registration
            SET age_dd = p_age_dd,
                age_mm = p_age_mm,
                age_yy = p_age_yy,
                dob = p_dob
          WHERE reg_no = p_reg_no;

         v_reg_no := p_reg_no;
         v_hospital_number := p_hospital_number;
      END IF;

      IF p_appoint_no IS NULL
      THEN
         OPEN c_con_type_prfx;

         FETCH c_con_type_prfx
          INTO v_consult_type_prifx;

         CLOSE c_con_type_prfx;

         k_general.pd_genarate_no ('SEQ_APPOINT_NO',
                                   p_company_no,
                                   p_appoint_no,
                                   'YY',
                                   10
                                  );
         k_general.pd_genarate_id (v_consult_type_prifx,
                                   'OPD_APPOINTMENT',
                                   'APPOINT_ID',
                                   p_company_no,
                                   v_appoint_id
                                  );

         IF p_appoint_no IS NULL OR v_appoint_id IS NULL
         THEN
            p_error := 'CANNOT GENERATE THE PRIMARY KEY APPOINTMENT NO';
         ELSE
            INSERT INTO opd_appointment
                        (appoint_no, appoint_id, appoint_date,
                         doctor_no, shiftdtl_no, consultation_type,
                         slot_sl, slot_no, start_time, end_time,
                         reg_no, salutation, patient_name,
                         phone_mobile, email, dob, age_dd, age_mm,
                         age_yy, gender, pat_type_no, bu_no,
                         m_status, address, blood_group,
                         appoint_type, appoint_status, chif_complain,
                         ss_creator, ss_created_on, ss_created_session,
                         company_no, app_from_flag
                        )
                 VALUES (p_appoint_no, v_appoint_id, p_appoint_date,
                         p_doctor_no, p_shiftdtl_no, p_consultation_type_no,
                         p_slot_sl, p_slot_no, p_start_time, p_end_time,
                         v_reg_no, p_salutation, p_patient_name,
                         p_phone_mobile, p_email, p_dob, p_age_dd, p_age_mm,
                         p_age_yy, p_gender, p_patient_type_no, p_bu_no,
                         p_m_status, p_address, p_blood_group,
                         p_appoint_type, 1, p_chif_complain,
                         p_ss_creator, SYSDATE, p_ss_created_session,
                         p_company_no, p_app_from_flag
                        );
         END IF;

         k_general.pd_genarate_no ('SEQ_OPD_CONSULTATION_NO',
                                   p_company_no,
                                   p_consultation_no,
                                   'YY',
                                   10
                                  );
         k_general.pd_genarate_id ('C',
                                   'OPD_CONSULTATION',
                                   'OPD_CONSULTATION_ID',
                                   p_company_no,
                                   p_consultation_id
                                  );

         IF p_consultation_no IS NULL OR p_consultation_id IS NULL
         THEN
            p_error := 'CANNOT GENERATE THE PRIMARY KEY CONSULTATION NO';
         ELSE
            INSERT INTO opd_consultation
                        (opd_consultation_no, opd_consultation_id,
                         doctor_no, consult_type_no,
                         consultation_date, consultation_datetime, reg_no,
                         appointment_no, consult_fee, ref_doctor_no,
                         consult_reason, next_followup_date, bu_no,
                         prescribed_admission_date, ss_creator,
                         ss_created_on, ss_created_session, company_no,
                         salesrep_no
                        )
                 VALUES (p_consultation_no, p_consultation_id,
                         p_doctor_no, p_consultation_type_no,
                         TRUNC (SYSDATE), SYSDATE, v_reg_no,
                         p_appoint_no, p_consult_fee, p_ref_doc_no,
                         p_chif_complain, p_next_followup_date, p_bu_no,
                         p_pres_admission_date, p_ss_creator,
                         SYSDATE, p_ss_created_session, p_company_no,
                         p_salesrep_no
                        );
         END IF;
      ELSE
         UPDATE opd_appointment
            SET reg_no = NVL (v_reg_no, p_reg_no)
          WHERE appoint_no = p_appoint_no;

         k_general.pd_genarate_no ('SEQ_OPD_CONSULTATION_NO',
                                   p_company_no,
                                   p_consultation_no,
                                   'YY',
                                   10
                                  );
         k_general.pd_genarate_id ('C',
                                   'OPD_CONSULTATION',
                                   'OPD_CONSULTATION_ID',
                                   p_company_no,
                                   p_consultation_id
                                  );

         IF p_consultation_no IS NULL OR p_consultation_id IS NULL
         THEN
            p_error := 'CANNOT GENERATE THE PRIMARY KEY CONSULTATION NO';
         ELSE
            INSERT INTO opd_consultation
                        (opd_consultation_no, opd_consultation_id,
                         doctor_no, consult_type_no,
                         consultation_date, consultation_datetime, reg_no,
                         appointment_no, consult_fee, ref_doctor_no,
                         consult_reason, next_followup_date, bu_no,
                         prescribed_admission_date, ss_creator,
                         ss_created_on, ss_created_session, company_no,
                         salesrep_no, remarks
                        )
                 VALUES (p_consultation_no, p_consultation_id,
                         p_doctor_no, p_consultation_type_no,
                         TRUNC (SYSDATE), SYSDATE, v_reg_no,
                         p_appoint_no, p_consult_fee, p_ref_doc_no,
                         p_chif_complain, p_next_followup_date, p_bu_no,
                         p_pres_admission_date, p_ss_creator,
                         SYSDATE, p_ss_created_session, p_company_no,
                         p_salesrep_no, p_remarks
                        );
         END IF;
      END IF;

      IF NVL (p_consult_fee, 0) > 0
      THEN
         FOR i IN 1 .. p_item_index
         LOOP
            i_item_no (i)               := p_item_no (i);
            i_item_name (i)             := p_item_name (i);
            i_item_qty (i)              := p_item_qty (i);
            i_item_rate (i)             := p_item_rate (i);
            i_item_vat (i)              := p_item_vat (i);
            i_urgent_fee (i)            := p_urgent_fee (i);
            i_service_charge (i)        := p_service_charge (i);
            i_itemtype_no (i)           := p_itemtype_no (i);
            i_par_itemtype_no (i)       := p_par_itemtype_no (i);
            i_bu_no (i)                 := p_bu_no;
            i_delivery_status_no (i)    := p_delivery_status_no (i);
            i_package_item_flag (i)     := p_package_item_flag (i);
            i_cli_disc_amt (i)          := p_cli_disc_amt (i);
         END LOOP;

         FOR j IN 1 .. p_pay_index
         LOOP
            j_pay_mode (j)          := p_pay_mode (j);
            j_coll_mode (j)         := p_coll_mode (j);
            j_pay_type_no (j)       := p_pay_type_no (j);
            j_pay_cqcc_others (j)   := p_pay_cqcc_others (j);
            j_pay_bank_name (j)     := p_pay_bank_name (j);
            j_pay_amt (j)           := p_pay_amt (j);
            j_given_amt (j)         := p_given_amt (j);
         END LOOP;

         IF p_consultation_no IS NOT NULL AND NVL (p_consult_fee, 0) > 0
         THEN
                 pd_invoice_web_cmh (p_reg_no         => v_reg_no,
                            p_hospital_number         => v_hospital_number,
                            p_pat_type_no             => p_patient_type_no,
                            p_admission_no            => NULL,
                            p_admission_id            => NULL,
                            p_consultation_no         => p_consultation_no,
                            p_bed_no                  => NULL,
                            p_salutation              => p_salutation,
                            p_fname                   => p_patient_name,
                            p_lname                   => NULL,
                            p_gender                  => p_gender,
                            p_m_status                => p_m_status,
                            p_age_dd                  => p_age_dd,
                            p_age_mm                  => p_age_mm,
                            p_age_yy                  => p_age_yy,
                            p_phone_mobile            => p_phone_mobile,
                            p_dob                     => p_dob,
                            p_address                 => p_address,
                            p_blood_group             => p_blood_group,
                            p_religion                => NULL,
                            p_email                   => p_email,
                            p_national_id             => NULL,
                            p_ref_doc_no              => p_ref_doc_no,
                            p_remarks                 => p_remarks,
                            p_delivery_date           => NULL,
                            p_bill_module_no          => 9,
                            p_item_no                 => i_item_no,
                            p_item_name               => i_item_name,
                            p_item_qty                => i_item_qty,
                            p_item_rate               => i_item_rate,
                            p_item_vat                => i_item_vat,
                            p_urgent_fee              => i_urgent_fee,
                            p_service_charge          => i_service_charge,
                            p_itemtype_no             => i_itemtype_no,
                            p_par_itemtype_no         => i_par_itemtype_no,
                            p_bu_no                   => i_bu_no,
                            p_delivery_status_no      => i_delivery_status_no,
                            p_package_item_flag       => i_package_item_flag,
                            p_cli_disc_amt            => i_cli_disc_amt,
                            p_item_index              => p_item_index,
                            p_cor_client_no           => p_cor_client_no,
                            p_cor_client_emp_id       => p_cor_client_emp_id,
                            p_card_no                 => p_card_no,
                            p_emp_no                  => p_emp_no,
                            p_relation_no             => p_relation_no,
                            p_pay_mode                => j_pay_mode,
                            p_coll_mode               => j_coll_mode,
                            p_pay_type_no             => j_pay_type_no,
                            p_pay_cqcc_others         => j_pay_cqcc_others,
                            p_pay_bank_name           => j_pay_bank_name,
                            p_pay_amt                 => j_pay_amt,
                            p_given_amt               => j_given_amt,
                            p_pay_index               => p_pay_index,
                            p_disc_amount             => p_disc_amount,
                            p_disctype_no             => p_disctype_no,
                            p_disc_auth_by            => p_disc_auth_by,
                            p_disc_remarks            => p_disc_remarks,
                            p_ss_creator              => p_ss_creator,
                            p_og_no                   => p_og_no,
                            p_company_no              => p_company_no,
                            p_ss_created_session      => p_ss_created_session,
                            p_invoice_no              => p_invoice_no,
                            p_invoice_id              => p_invoice_id,
                            p_error                   => p_error
                           );
             
            
                              
         ELSE
             p_error := 'Bill cannot be generated.';
                   
         END IF;
      END IF;

      IF p_error IS NULL
      THEN
         COMMIT;
      ELSE
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
         ROLLBACK;
   END pd_cosnultation_bill_web;
   
PROCEDURE pd_invoice_web_cmh (
      p_reg_no               IN       NUMBER DEFAULT NULL,
      p_hospital_number      IN       VARCHAR2 DEFAULT NULL,
      p_pat_type_no          IN       NUMBER DEFAULT NULL,
      p_admission_no         IN       NUMBER DEFAULT NULL,
      p_admission_id         IN       VARCHAR2 DEFAULT NULL,
      p_consultation_no      IN       NUMBER DEFAULT NULL,
      p_bed_no               IN       NUMBER DEFAULT NULL,
      p_salutation           IN       VARCHAR2,
      p_fname                IN       VARCHAR2,
      p_lname                IN       VARCHAR2,
      p_gender               IN       VARCHAR2,
      p_m_status             IN       VARCHAR2,
      p_age_dd               IN       NUMBER,
      p_age_mm               IN       NUMBER,
      p_age_yy               IN       NUMBER,
      p_phone_mobile         IN       VARCHAR2,
      p_dob                  IN       DATE DEFAULT NULL,
      p_address              IN       VARCHAR2 DEFAULT NULL,
      p_blood_group          IN       VARCHAR2 DEFAULT NULL,
      p_religion             IN       VARCHAR2 DEFAULT NULL,
      p_email                IN       VARCHAR2 DEFAULT NULL,
      p_national_id          IN       VARCHAR2 DEFAULT NULL,
      p_ref_doc_no           IN       NUMBER DEFAULT NULL,
      p_remarks              IN       VARCHAR2 DEFAULT NULL,
      p_delivery_date        IN       DATE DEFAULT NULL,
      p_bill_module_no       IN       NUMBER,
      p_item_no              IN       k_opd.arlist_numb,
      p_item_name            IN       k_opd.arlist_varc,
      p_item_qty             IN       k_opd.arlist_numb,
      p_item_rate            IN       k_opd.arlist_numb,
      p_item_vat             IN       k_opd.arlist_numb,
      p_urgent_fee           IN       k_opd.arlist_numb,
      p_service_charge       IN       k_opd.arlist_numb,
      p_itemtype_no          IN       k_opd.arlist_numb,
      p_par_itemtype_no      IN       k_opd.arlist_numb,
      p_bu_no                IN       k_opd.arlist_numb,
      p_delivery_status_no   IN       k_opd.arlist_numb,
      p_package_item_flag    IN       k_opd.arlist_numb,
      p_cli_disc_amt         IN       k_opd.arlist_numb,
      p_item_index           IN       NUMBER,
      p_cor_client_no        IN       NUMBER DEFAULT NULL,
      p_cor_client_emp_id    IN       VARCHAR2 DEFAULT NULL,
      p_emp_no               IN       NUMBER DEFAULT NULL,
      p_relation_no          IN       NUMBER DEFAULT NULL,
      p_card_no              IN       NUMBER DEFAULT NULL,
      p_pay_mode             IN       k_opd.arlist_numb,
      p_coll_mode            IN       k_opd.arlist_numb,
      p_pay_type_no          IN       k_opd.arlist_numb,
      p_pay_cqcc_others      IN       k_opd.arlist_varc,
      p_pay_bank_name        IN       k_opd.arlist_varc,
      p_pay_amt              IN       k_opd.arlist_numb,
      p_given_amt            IN       k_opd.arlist_numb,
      p_pay_index            IN       NUMBER DEFAULT 0,
      p_disc_amount          IN       NUMBER DEFAULT NULL,
      p_disctype_no          IN       NUMBER DEFAULT NULL,
      p_disc_auth_by         IN       NUMBER DEFAULT NULL,
      p_disc_remarks         IN       VARCHAR2 DEFAULT NULL,
      p_ss_creator           IN       NUMBER,
      p_og_no                IN       NUMBER,
      p_company_no           IN       NUMBER,
      p_ss_created_session   IN       NUMBER,
      p_invoice_no           OUT      NUMBER,
      p_invoice_id           OUT      VARCHAR2,
      p_error                OUT      VARCHAR2
   )
   AS
      CURSOR c_config
      IS
         SELECT hn_prifix, opd_invoice_prifix, invoince_method
           FROM opd_config
          WHERE company_no = p_company_no;

      r_c_config             c_config%ROWTYPE;
      v_reg_no               NUMBER;
      v_hospital_number      VARCHAR2 (50);
      v_bill_index           NUMBER               := 1;
      v_pay_index            NUMBER               := 1;
      v_invoicedtl_no        NUMBER;
      v_lab_exist            NUMBER               := 0;
      v_pay_no               NUMBER;
      v_pay_id               VARCHAR2 (50);
      v_paydtl_no            NUMBER;
      i_invoicedtl_no        k_ledger.arlist_numb;
      i_item_no              k_ledger.arlist_numb;
      i_item_name            k_ledger.arlist_varc;
      i_item_qty             k_ledger.arlist_numb;
      i_item_rate            k_ledger.arlist_numb;
      i_item_vat             k_ledger.arlist_numb;
      i_urgent_fee           k_ledger.arlist_numb;
      i_service_charge       k_ledger.arlist_numb;
      i_itemtype_no          k_ledger.arlist_numb;
      i_par_itemtype_no      k_ledger.arlist_numb;
      i_bu_no                k_ledger.arlist_numb;
      i_delivery_status_no   k_ledger.arlist_numb;
      i_package_item_flag    k_ledger.arlist_numb;
      i_pur_rate             k_ledger.arlist_numb;
      i_pay_no               k_ledger.arlist_numb;
      i_pay_mode             k_ledger.arlist_numb;
      i_coll_mode            k_ledger.arlist_numb;
      i_pay_type_no          k_ledger.arlist_numb;
      i_amount               k_ledger.arlist_numb;
      i_given_amt            k_ledger.arlist_numb;
   BEGIN
      OPEN c_config;

      FETCH c_config
       INTO r_c_config;

      CLOSE c_config;

      IF p_reg_no IS NULL
      THEN
         k_general.pd_genarate_id (r_c_config.hn_prifix,
                                   'OPD_REGISTRATION',
                                   'HOSPITAL_NUMBER',
                                   p_company_no,
                                   v_hospital_number
                                  );
         k_general.pd_genarate_no ('SEQ_REG_NO',
                                   p_company_no,
                                   v_reg_no,
                                   'YY',
                                   10
                                  );

         INSERT INTO opd_registration
                     (reg_no, hospital_number, reg_date, salutation,
                      fname, lname, gender, m_status, age_dd,
                      age_mm, age_yy, dob, blood_group, religion,
                      phone_mobile, email, address, national_id,
                      pat_type_no, reg_point, ss_creator, ss_created_on,
                      ss_created_session, company_no
                     )
              VALUES (v_reg_no, v_hospital_number, SYSDATE, p_salutation,
                      p_fname, p_lname, p_gender, p_m_status, p_age_dd,
                      p_age_mm, p_age_yy, p_dob, p_blood_group, p_religion,
                      p_phone_mobile, p_email, p_address, p_national_id,
                      p_pat_type_no, 5, p_ss_creator, SYSDATE,
                      p_ss_created_session, p_company_no
                     );
      ELSE
         v_reg_no := p_reg_no;
      END IF;

      k_general.pd_genarate_no ('SEQ_INVOICE_NO',
                                p_company_no,
                                p_invoice_no,
                                'YY',
                                10
                               );

      IF r_c_config.invoince_method IS NULL
      THEN
         k_general.pd_genarate_id (r_c_config.opd_invoice_prifix,
                                   'OPD_INVOICE',
                                   'OPD_INVOICE_ID',
                                   p_company_no,
                                   p_invoice_id
                                  );
      ELSE
         EXECUTE IMMEDIATE    'SELECT '
                           || r_c_config.invoince_method
                           || ' FROM SYS.DUAL'
                      INTO p_invoice_id;
      END IF;
      

--      INSERT INTO opd_invoice
--                  (opd_invoice_no, opd_invoice_id, bill_module_no, reg_no,
--                   admission_no, admission_id, consultation_no,
--                   invoice_date, invoice_datetime, doctor_no, remarks,
--                   bu_no, cor_client_no, cor_client_card_no,
--                   emp_no, relation_no, pat_type_no, ss_creator,
--                   ss_created_on, ss_created_session, company_no, card_no
--                  )
--           VALUES (p_invoice_no, p_invoice_id, p_bill_module_no, v_reg_no,
--                   p_admission_no, p_admission_id, p_consultation_no,
--                   TRUNC (SYSDATE), SYSDATE, p_ref_doc_no, p_remarks,
--                   p_bu_no (1), p_cor_client_no, p_cor_client_emp_id,
--                   p_emp_no, p_relation_no, p_pat_type_no, p_ss_creator,
--                   SYSDATE, p_ss_created_session, p_company_no, p_card_no
--                  );
insert into bill_invoice (invoice_no, invoice_id, bill_module_no, reg_no, 
                                  admission_no, admission_id, consultation_no, invoice_date, 
                                  invoice_datetime, ref_doc_no,  remarks, 
                                  emp_no, relation_no,card_no, rep_sort_no,
                                  report_delivary_date,report_delivary_datetime ,
                                  pat_type_no, ss_creator, ss_created_on, 
                                  ss_created_session, company_no,BU_NO)
                                  
        values (p_invoice_no, p_invoice_id, p_bill_module_no, v_reg_no,
                p_admission_no, p_admission_id, p_consultation_no, trunc(sysdate),
                sysdate, p_ref_doc_no, p_remarks,
                p_emp_no, p_relation_no,p_card_no ,null,
                sysdate,sysdate,
                p_pat_type_no, p_ss_creator, sysdate, 
                p_ss_created_session, p_company_no,p_bu_no(v_bill_index) );


      LOOP
         k_general.pd_genarate_no ('SEQ_INVOICEDTL_NO',
                                   p_company_no,
                                   v_invoicedtl_no,
                                   'YY',
                                   10
                                  );

--         INSERT INTO opd_invoicedtl
--                     (opd_invoicedtl_no, opd_invoice_no,
--                      item_no, item_name,
--                      itemtype_no,
--                      item_qty, item_rate,
--                      item_vat, urgent_fee,
--                      service_charge,
--                      package_item_flag,
--                      bu_no, ss_creator, ss_created_on,
--                      ss_created_session, company_no
--                     )
--              VALUES (v_invoicedtl_no, p_invoice_no,
--                      p_item_no (v_bill_index), p_item_name (v_bill_index),
--                      p_itemtype_no (v_bill_index),
--                      p_item_qty (v_bill_index), p_item_rate (v_bill_index),
--                      p_item_vat (v_bill_index), p_urgent_fee (v_bill_index),
--                      p_service_charge (v_bill_index),
--                      p_package_item_flag (v_bill_index),
--                      p_bu_no (v_bill_index), p_ss_creator, SYSDATE,
--                      p_ss_created_session, p_company_no
--                     );


insert into bill_invoicedtl(invoicedtl_no, invoice_no, item_no, item_name, 
                                itemtype_no, item_qty, item_rate, item_vat, 
                                urgent_fee, service_charge,
                                package_item_flag, bu_no, rep_item_name, 
                                ss_creator, ss_created_on, ss_created_session, company_no,BILL_MODULE_NO)
                                            
                        values(v_invoicedtl_no, p_invoice_no, p_item_no (v_bill_index), p_item_name (v_bill_index), 
                               p_itemtype_no (v_bill_index), p_item_qty (v_bill_index), p_item_rate (v_bill_index), p_item_vat (v_bill_index), 
                               p_urgent_fee (v_bill_index), p_service_charge (v_bill_index),
                               p_package_item_flag (v_bill_index), p_bu_no (v_bill_index), p_item_name (v_bill_index), 
                               p_ss_creator, sysdate, p_ss_created_session, p_company_no,p_bill_module_no);


         i_invoicedtl_no (v_bill_index) := v_invoicedtl_no;
         i_item_no (v_bill_index) := p_item_no (v_bill_index);
         i_item_name (v_bill_index) := p_item_name (v_bill_index);
         i_item_qty (v_bill_index) := p_item_qty (v_bill_index);
         i_item_rate (v_bill_index) := p_item_rate (v_bill_index);
         i_item_vat (v_bill_index) := p_item_vat (v_bill_index);
         i_urgent_fee (v_bill_index) := p_urgent_fee (v_bill_index);
         i_service_charge (v_bill_index) := p_service_charge (v_bill_index);
         i_itemtype_no (v_bill_index) := p_itemtype_no (v_bill_index);
         i_par_itemtype_no (v_bill_index) := p_par_itemtype_no (v_bill_index);
         i_bu_no (v_bill_index) := p_bu_no (v_bill_index);
         i_delivery_status_no (v_bill_index) :=
                                           p_delivery_status_no (v_bill_index);
         i_package_item_flag (v_bill_index) :=
                                            p_package_item_flag (v_bill_index);
         i_pur_rate (v_bill_index) := NULL;
         EXIT WHEN v_bill_index >= NVL (p_item_index, 0);
         v_bill_index := v_bill_index + 1;
      END LOOP;

      k_ledger.pd_ledger_bill (p_reg_no                  => v_reg_no,
                               p_invoice_no              => p_invoice_no,
                               p_invoice_id              => p_invoice_id,
                               p_bill_module_no          => p_bill_module_no,
                               p_admission_no            => p_admission_no,
                               p_admission_id            => p_admission_id,
                               p_consultation_no         => p_consultation_no,
                               p_ref_doc_no              => p_ref_doc_no,
                               p_second_ref_doc_no       => NULL,
                               p_doctor_no               => p_ref_doc_no,
                               p_invoicedtl_no           => i_invoicedtl_no,
                               p_item_no                 => i_item_no,
                               p_item_name               => i_item_name,
                               p_item_qty                => i_item_qty,
                               p_item_rate               => i_item_rate,
                               p_item_vat                => i_item_vat,
                               p_urgent_fee              => i_urgent_fee,
                               p_service_charge          => i_service_charge,
                               p_itemtype_no             => i_itemtype_no,
                               p_par_itemtype_no         => i_par_itemtype_no,
                               p_bu_no                   => i_bu_no,
                               p_delivery_status_no      => i_delivery_status_no,
                               p_package_item_flag       => i_package_item_flag,
                               p_pur_rate                => i_pur_rate,
                               p_inv_index               => v_bill_index,
                               p_bed_no                  => p_bed_no,
                               p_ss_creator              => p_ss_creator,
                               p_og_no                   => p_og_no,
                               p_company_no              => p_company_no,
                               p_ss_created_session      => p_ss_created_session,
                               p_error                   => p_error
                              );
      v_bill_index := 1;

      IF NVL (p_disc_amount, 0) > 0
      THEN
         k_general.pd_genarate_id ('',
                                   'BILL_PAYMENT',
                                   'PAY_ID',
                                   p_company_no,
                                   v_pay_id
                                  );
         k_general.pd_genarate_no ('SEQ_PAY_NO',
                                   p_company_no,
                                   v_pay_no,
                                   'YY',
                                   10
                                  );

         INSERT INTO bill_payment
                     (pay_no, pay_id, pay_date, pay_datetime,
                      bill_module_no, reg_no, invoice_no,
                      admission_no, disc_type_no, pay_amt, pay_type_no,
                      disc_auth_by, disc_remarks, ss_creator, ss_created_on,
                      ss_created_session, company_no
                     )
              VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                      p_bill_module_no, v_reg_no, p_invoice_no,
                      p_admission_no, p_disctype_no, p_disc_amount, 6,
                      p_disc_auth_by, p_disc_remarks, p_ss_creator, SYSDATE,
                      p_ss_created_session, p_company_no
                     );

         LOOP
            k_general.pd_genarate_no ('SEQ_PAYDTL_NO',
                                      p_company_no,
                                      v_paydtl_no,
                                      'YY',
                                      10
                                     );

            INSERT INTO bill_paymentdtl
                        (paydtl_no, pay_no, pay_date, pay_datetime,
                         reg_no, invoice_no,
                         invoicedtl_no, admission_no,
                         item_no, bill_module_no,
                         disc_type_no, cli_disc_amt,
                         ss_creator, ss_created_on, ss_created_session,
                         company_no
                        )
                 VALUES (v_paydtl_no, v_pay_no, TRUNC (SYSDATE), SYSDATE,
                         v_reg_no, p_invoice_no,
                         i_invoicedtl_no (v_bill_index), p_admission_no,
                         p_item_no (v_bill_index), p_bill_module_no,
                         p_disctype_no, p_cli_disc_amt (v_bill_index),
                         p_ss_creator, SYSDATE, p_ss_created_session,
                         p_company_no
                        );

            EXIT WHEN v_bill_index >= NVL (p_item_index, 0);
            v_bill_index := v_bill_index + 1;
         END LOOP;

         i_pay_no (1) := v_pay_no;
         i_pay_mode (1) := NULL;
         i_coll_mode (1) := NULL;
         i_pay_type_no (1) := 6;
         i_amount (1) := p_disc_amount;
         i_given_amt (1) := NULL;
         k_ledger.pd_ledger (p_reg_no                  => v_reg_no,
                             p_invoice_no              => p_invoice_no,
                             p_invoice_id              => p_invoice_id,
                             p_bill_module_no          => p_bill_module_no,
                             p_admission_no            => p_admission_no,
                             p_admission_id            => p_admission_id,
                             p_consultation_no         => p_consultation_no,
                             p_pay_no                  => i_pay_no,
                             p_pay_mode                => i_pay_mode,
                             p_coll_mode               => i_coll_mode,
                             p_pay_type_no             => i_pay_type_no,
                             p_amount                  => i_amount,
                             p_given_amt               => i_given_amt,
                             p_index                   => 1,
                             p_disctype_no             => p_disctype_no,
                             p_disc_auth_by            => p_disc_auth_by,
                             p_bed_no                  => p_bed_no,
                             p_ss_creator              => p_ss_creator,
                             p_og_no                   => p_og_no,
                             p_company_no              => p_company_no,
                             p_ss_created_session      => p_ss_created_session,
                             p_error                   => p_error
                            );
      END IF;

      IF NVL (p_pay_index, 0) > 0
      THEN
         LOOP
            k_general.pd_genarate_id ('',
                                      'BILL_PAYMENT',
                                      'PAY_ID',
                                      p_company_no,
                                      v_pay_id
                                     );
            k_general.pd_genarate_no ('SEQ_PAY_NO',
                                      p_company_no,
                                      v_pay_no,
                                      'YY',
                                      10
                                     );

            INSERT INTO bill_payment
                        (pay_no, pay_id, pay_date, pay_datetime,
                         bill_module_no, reg_no, invoice_no,
                         admission_no, pay_amt,
                         pay_type_no,
                         pay_mode, coll_mode,
                         pay_cqcc_others,
                         pay_bank_name,
                         given_amt, ss_creator, ss_created_on,
                         ss_created_session, company_no
                        )
                 VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                         p_bill_module_no, v_reg_no, p_invoice_no,
                         p_admission_no, p_pay_amt (v_pay_index),
                         p_pay_type_no (v_pay_index),
                         p_pay_mode (v_pay_index), p_coll_mode (v_pay_index),
                         p_pay_cqcc_others (v_pay_index),
                         p_pay_bank_name (v_pay_index),
                         p_given_amt (v_pay_index), p_ss_creator, SYSDATE,
                         p_ss_created_session, p_company_no
                        );

            i_pay_no (v_pay_index) := v_pay_no;
            i_pay_mode (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt (v_pay_index) := p_given_amt (v_pay_index);
            EXIT WHEN v_pay_index >= NVL (p_pay_index, 0);
            v_pay_index := v_pay_index + 1;
         END LOOP;

         k_ledger.pd_ledger (p_reg_no                  => v_reg_no,
                             p_invoice_no              => p_invoice_no,
                             p_invoice_id              => p_invoice_id,
                             p_bill_module_no          => p_bill_module_no,
                             p_admission_no            => p_admission_no,
                             p_admission_id            => p_admission_id,
                             p_consultation_no         => p_consultation_no,
                             p_pay_no                  => i_pay_no,
                             p_pay_mode                => i_pay_mode,
                             p_coll_mode               => i_coll_mode,
                             p_pay_type_no             => i_pay_type_no,
                             p_amount                  => i_amount,
                             p_given_amt               => i_given_amt,
                             p_index                   => v_pay_index,
                             p_disctype_no             => NULL,
                             p_disc_auth_by            => NULL,
                             p_bed_no                  => p_bed_no,
                             p_ss_creator              => p_ss_creator,
                             p_og_no                   => p_og_no,
                             p_company_no              => p_company_no,
                             p_ss_created_session      => p_ss_created_session,
                             p_error                   => p_error
                            );
      END IF;

      IF p_error IS NULL
      THEN
         COMMIT;
      ELSE
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
         ROLLBACK;
   END pd_invoice_web_cmh;
   ---NEW ADD --
      PROCEDURE pd_item_disc_cancel_web (
      p_invoice_no           IN       NUMBER,
      p_disc_time            IN       NUMBER,
      --0 - all, 1 - initial, 2 - second
      p_bill_module_no       IN       NUMBER,
      p_invoicedtl_no        IN       k_opd.arlist_numb,
      p_item_no              IN       k_opd.arlist_numb,
      p_item_qty             IN       k_opd.arlist_numb,
      p_index                IN       NUMBER,
      p_ss_creator           IN       NUMBER,
      p_og_no                IN       NUMBER,
      p_company_no           IN       NUMBER,
      p_ss_created_session   IN       NUMBER,
      p_error                OUT      VARCHAR2
   )
   IS
      CURSOR c_bill_info
      IS
         SELECT invoice_id invoice_id, reg_no, admission_no,
                admission_id, consultation_no,
                CASE
                   WHEN admission_no IS NOT NULL
                      THEN k_ipd.fd_current_bed_no (admission_no)
                   ELSE NULL
                END bed_no
           FROM bill_invoice
          WHERE invoice_no = p_invoice_no;

      r_c_bill_info            c_bill_info%ROWTYPE;

      CURSOR c_disc_ini (p_invoicedtl NUMBER, p_item NUMBER)
      IS
         SELECT   disc_type_no,
                  SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0))
                                                                    cli_disc,
                  SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0))
                                                                    ref_disc
             FROM bill_paymentdtl pd
            WHERE invoice_no = p_invoice_no
              AND item_no = p_item
              AND invoicedtl_no = p_invoicedtl
              AND EXISTS (
                          SELECT pay_no
                            FROM bill_payment p
                           WHERE p.pay_no = pd.pay_no
                                 AND pay_type_no IN (6, 8))
         GROUP BY disc_type_no
           HAVING SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0)) > 0
               OR SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0)) > 0
         ORDER BY disc_type_no;

      CURSOR c_disc_sec (p_invoicedtl NUMBER, p_item NUMBER)
      IS
         SELECT   disc_type_no,
                  SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0))
                                                                     cli_disc,
                  SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0))
                                                                     ref_disc
             FROM bill_paymentdtl pd
            WHERE invoice_no = p_invoice_no
              AND item_no = p_item
              AND invoicedtl_no = p_invoicedtl
              AND EXISTS (
                          SELECT pay_no
                            FROM bill_payment p
                           WHERE p.pay_no = pd.pay_no
                                 AND pay_type_no IN (7, 9))
         GROUP BY disc_type_no
           HAVING SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0)) > 0
               OR SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0)) > 0
         ORDER BY disc_type_no;

      CURSOR c_item_qty (p_invoicedtl NUMBER, p_item NUMBER)
      IS
         SELECT item_qty - NVL (cancel_qty, 0) bill_item
           FROM bill_invoicedtl
          WHERE invoice_no = p_invoice_no
            AND invoicedtl_no = p_invoicedtl
            AND item_no = p_item;

      r_c_item_qty             c_item_qty%ROWTYPE;
      v_index                  NUMBER                  := 1;
      v_index_ini              NUMBER                  := 0;
      v_index_sec              NUMBER                  := 0;
      v_index_pay_ini          NUMBER                  := 1;
      v_index_pay_sec          NUMBER                  := 1;
      v_tot_disc_ini           k_financial.arlist_numb;
      v_tot_disc_sec           k_financial.arlist_numb;
      v_pay_disc_type_no_ini   k_financial.arlist_numb;
      v_pay_disc_type_no_sec   k_financial.arlist_numb;
      v_pay_disc_type_ini      NUMBER;
      v_pay_disc_type_sec      NUMBER;
      v_disc_type_no_ini       k_financial.arlist_numb;
      v_cli_disc_ref_ini       k_financial.arlist_numb;
      v_ref_disc_ref_ini       k_financial.arlist_numb;
      v_disc_type_no_sec       k_financial.arlist_numb;
      v_cli_disc_ref_sec       k_financial.arlist_numb;
      v_ref_disc_ref_sec       k_financial.arlist_numb;
      v_item_no_ini            k_financial.arlist_numb;
      v_item_no_sec            k_financial.arlist_numb;
      v_invoicedtl_no_ini      k_financial.arlist_numb;
      v_invoicedtl_no_sec      k_financial.arlist_numb;
      p_pay_mode               k_financial.arlist_numb;
      p_coll_mode              k_financial.arlist_numb;
      p_pay_type_no            k_financial.arlist_numb;
      p_pay_cqcc_others        k_financial.arlist_varc;
      p_pay_bank_name          k_financial.arlist_varc;
      p_amount                 k_financial.arlist_numb;
      p_given_amt              k_financial.arlist_numb;
      i_pay_no                 k_ledger.arlist_numb;
      i_pay_mode               k_ledger.arlist_numb;
      i_coll_mode              k_ledger.arlist_numb;
      i_pay_type_no            k_ledger.arlist_numb;
      i_amount                 k_ledger.arlist_numb;
      i_given_amt              k_ledger.arlist_numb;
      v_pay_no                 NUMBER;
      v_pay_id                 VARCHAR2 (50);
      v_paydtl_no              NUMBER;
   BEGIN
      IF p_disc_time = 0
      THEN
         v_index := 1;

         LOOP
            FOR r_c_disc_ini IN c_disc_ini (p_invoicedtl_no (v_index),
                                            p_item_no (v_index)
                                           )
            LOOP
               v_index_ini := v_index_ini + 1;

               OPEN c_item_qty (p_invoicedtl_no (v_index),
                                p_item_no (v_index)
                               );

               FETCH c_item_qty
                INTO r_c_item_qty;

               CLOSE c_item_qty;

               IF r_c_item_qty.bill_item <> p_item_qty (v_index)
               THEN
                  IF r_c_disc_ini.cli_disc > 0
                  THEN
                     v_cli_disc_ref_ini (v_index_ini) :=
                        NVL (ROUND (  r_c_disc_ini.cli_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_cli_disc_ref_ini (v_index_ini) := 0;
                  END IF;

                  IF r_c_disc_ini.ref_disc > 0
                  THEN
                     v_ref_disc_ref_ini (v_index_ini) :=
                        NVL (ROUND (  r_c_disc_ini.ref_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_ref_disc_ref_ini (v_index_ini) := 0;
                  END IF;

                  v_disc_type_no_ini (v_index_ini) :=
                                                     r_c_disc_ini.disc_type_no;
                  v_item_no_ini (v_index_ini) := p_item_no (v_index);
                  v_invoicedtl_no_ini (v_index_ini) :=
                                                     p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_ini IS NULL
                  THEN
                     v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                     v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                     v_tot_disc_ini (v_index_pay_ini) :=
                          v_cli_disc_ref_ini (v_index_ini)
                        + v_ref_disc_ref_ini (v_index_ini);
                  ELSE
                     IF v_pay_disc_type_ini = r_c_disc_ini.disc_type_no
                     THEN
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_tot_disc_ini (v_index_pay_ini)
                           + v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     ELSE
                        v_index_pay_ini := v_index_pay_ini + 1;
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     END IF;
                  END IF;
               ELSE
                  v_cli_disc_ref_ini (v_index_ini) :=
                                               NVL (r_c_disc_ini.cli_disc, 0);
                  v_ref_disc_ref_ini (v_index_ini) :=
                                               NVL (r_c_disc_ini.ref_disc, 0);
                  v_disc_type_no_ini (v_index_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                  v_item_no_ini (v_index_ini) := p_item_no (v_index);
                  v_invoicedtl_no_ini (v_index_ini) :=
                                                    p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_ini IS NULL
                  THEN
                     v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                     v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                     v_tot_disc_ini (v_index_pay_ini) :=
                          v_cli_disc_ref_ini (v_index_ini)
                        + v_ref_disc_ref_ini (v_index_ini);
                  ELSE
                     IF v_pay_disc_type_ini = r_c_disc_ini.disc_type_no
                     THEN
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_tot_disc_ini (v_index_pay_ini)
                           + v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     ELSE
                        v_index_pay_ini := v_index_pay_ini + 1;
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     END IF;
                  END IF;
               END IF;
            END LOOP;

            EXIT WHEN v_index >= NVL (p_index, 0);
            v_index := v_index + 1;
         END LOOP;

         v_index := 1;

         LOOP
            FOR r_c_disc_sec IN c_disc_sec (p_invoicedtl_no (v_index),
                                            p_item_no (v_index)
                                           )
            LOOP
               v_index_sec := v_index_sec + 1;

               OPEN c_item_qty (p_invoicedtl_no (v_index),
                                p_item_no (v_index)
                               );

               FETCH c_item_qty
                INTO r_c_item_qty;

               CLOSE c_item_qty;

               IF r_c_item_qty.bill_item <> p_item_qty (v_index)
               THEN
                  IF r_c_disc_sec.cli_disc > 0
                  THEN
                     v_cli_disc_ref_sec (v_index_sec) :=
                        NVL (ROUND (  r_c_disc_sec.cli_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_cli_disc_ref_sec (v_index_sec) := 0;
                  END IF;

                  IF r_c_disc_sec.ref_disc > 0
                  THEN
                     v_ref_disc_ref_sec (v_index_sec) :=
                        NVL (ROUND (  r_c_disc_sec.ref_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_ref_disc_ref_sec (v_index_sec) := 0;
                  END IF;

                  v_disc_type_no_sec (v_index_sec) :=
                                                     r_c_disc_sec.disc_type_no;
                  v_item_no_sec (v_index_sec) := p_item_no (v_index);
                  v_invoicedtl_no_sec (v_index_sec) :=
                                                     p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_sec IS NULL
                  THEN
                     v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                     v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                     v_tot_disc_sec (v_index_pay_sec) :=
                          v_cli_disc_ref_sec (v_index_sec)
                        + v_ref_disc_ref_sec (v_index_sec);
                  ELSE
                     IF v_pay_disc_type_sec = r_c_disc_sec.disc_type_no
                     THEN
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_tot_disc_sec (v_index_pay_sec)
                           + v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     ELSE
                        v_index_pay_sec := v_index_pay_sec + 1;
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     END IF;
                  END IF;
               ELSE
                  v_cli_disc_ref_sec (v_index_sec) :=
                                               NVL (r_c_disc_sec.cli_disc, 0);
                  v_ref_disc_ref_sec (v_index_sec) :=
                                               NVL (r_c_disc_sec.ref_disc, 0);
                  v_disc_type_no_sec (v_index_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                  v_item_no_sec (v_index_sec) := p_item_no (v_index);
                  v_invoicedtl_no_sec (v_index_sec) :=
                                                    p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_sec IS NULL
                  THEN
                     v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                     v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                     v_tot_disc_sec (v_index_pay_sec) :=
                          v_cli_disc_ref_sec (v_index_sec)
                        + v_ref_disc_ref_sec (v_index_sec);
                  ELSE
                     IF v_pay_disc_type_sec = r_c_disc_sec.disc_type_no
                     THEN
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_tot_disc_sec (v_index_pay_sec)
                           + v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     ELSE
                        v_index_pay_sec := v_index_pay_sec + 1;
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     END IF;
                  END IF;
               END IF;
            END LOOP;

            EXIT WHEN v_index >= NVL (p_index, 0);
            v_index := v_index + 1;
         END LOOP;
      ELSIF p_disc_time = 1
      THEN
         v_index := 1;

         LOOP
            FOR r_c_disc_ini IN c_disc_ini (p_invoicedtl_no (v_index),
                                            p_item_no (v_index)
                                           )
            LOOP
               v_index_ini := v_index_ini + 1;

               OPEN c_item_qty (p_invoicedtl_no (v_index),
                                p_item_no (v_index)
                               );

               FETCH c_item_qty
                INTO r_c_item_qty;

               CLOSE c_item_qty;

               IF r_c_item_qty.bill_item <> p_item_qty (v_index)
               THEN
                  IF r_c_disc_ini.cli_disc > 0
                  THEN
                     v_cli_disc_ref_ini (v_index_ini) :=
                        NVL (ROUND (  r_c_disc_ini.cli_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_cli_disc_ref_ini (v_index_ini) := 0;
                  END IF;

                  IF r_c_disc_ini.ref_disc > 0
                  THEN
                     v_ref_disc_ref_ini (v_index_ini) :=
                        NVL (ROUND (  r_c_disc_ini.ref_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_ref_disc_ref_ini (v_index_ini) := 0;
                  END IF;

                  v_disc_type_no_ini (v_index_ini) :=
                                                     r_c_disc_ini.disc_type_no;
                  v_item_no_ini (v_index_ini) := p_item_no (v_index);
                  v_invoicedtl_no_ini (v_index_ini) :=
                                                     p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_ini IS NULL
                  THEN
                     v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                     v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                     v_tot_disc_ini (v_index_pay_ini) :=
                          v_cli_disc_ref_ini (v_index_ini)
                        + v_ref_disc_ref_ini (v_index_ini);
                  ELSE
                     IF v_pay_disc_type_ini = r_c_disc_ini.disc_type_no
                     THEN
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_tot_disc_ini (v_index_pay_ini)
                           + v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     ELSE
                        v_index_pay_ini := v_index_pay_ini + 1;
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     END IF;
                  END IF;
               ELSE
                  v_cli_disc_ref_ini (v_index_ini) :=
                                               NVL (r_c_disc_ini.cli_disc, 0);
                  v_ref_disc_ref_ini (v_index_ini) :=
                                               NVL (r_c_disc_ini.ref_disc, 0);
                  v_disc_type_no_ini (v_index_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                  v_item_no_ini (v_index_ini) := p_item_no (v_index);
                  v_invoicedtl_no_ini (v_index_ini) :=
                                                    p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_ini IS NULL
                  THEN
                     v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                     v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                     v_tot_disc_ini (v_index_pay_ini) :=
                          v_cli_disc_ref_ini (v_index_ini)
                        + v_ref_disc_ref_ini (v_index_ini);
                  ELSE
                     IF v_pay_disc_type_ini = r_c_disc_ini.disc_type_no
                     THEN
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_tot_disc_ini (v_index_pay_ini)
                           + v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     ELSE
                        v_index_pay_ini := v_index_pay_ini + 1;
                        v_pay_disc_type_ini := r_c_disc_ini.disc_type_no;
                        v_pay_disc_type_no_ini (v_index_pay_ini) :=
                                                    r_c_disc_ini.disc_type_no;
                        v_tot_disc_ini (v_index_pay_ini) :=
                             v_cli_disc_ref_ini (v_index_ini)
                           + v_ref_disc_ref_ini (v_index_ini);
                     END IF;
                  END IF;
               END IF;
            END LOOP;

            EXIT WHEN v_index >= NVL (p_index, 0);
            v_index := v_index + 1;
         END LOOP;
      ELSIF p_disc_time = 2
      THEN
         v_index := 1;

         LOOP
            FOR r_c_disc_sec IN c_disc_sec (p_invoicedtl_no (v_index),
                                            p_item_no (v_index)
                                           )
            LOOP
               v_index_sec := v_index_sec + 1;

               OPEN c_item_qty (p_invoicedtl_no (v_index),
                                p_item_no (v_index)
                               );

               FETCH c_item_qty
                INTO r_c_item_qty;

               CLOSE c_item_qty;

               IF r_c_item_qty.bill_item <> p_item_qty (v_index)
               THEN
                  IF r_c_disc_sec.cli_disc > 0
                  THEN
                     v_cli_disc_ref_sec (v_index_sec) :=
                        NVL (ROUND (  r_c_disc_sec.cli_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_cli_disc_ref_sec (v_index_sec) := 0;
                  END IF;

                  IF r_c_disc_sec.ref_disc > 0
                  THEN
                     v_ref_disc_ref_sec (v_index_sec) :=
                        NVL (ROUND (  r_c_disc_sec.ref_disc
                                    / r_c_item_qty.bill_item
                                    * p_item_qty (v_index)
                                   ),
                             0
                            );
                  ELSE
                     v_ref_disc_ref_sec (v_index_sec) := 0;
                  END IF;

                  v_disc_type_no_sec (v_index_sec) :=
                                                     r_c_disc_sec.disc_type_no;
                  v_item_no_sec (v_index_sec) := p_item_no (v_index);
                  v_invoicedtl_no_sec (v_index_sec) :=
                                                     p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_sec IS NULL
                  THEN
                     v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                     v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                     v_tot_disc_sec (v_index_pay_sec) :=
                          v_cli_disc_ref_sec (v_index_sec)
                        + v_ref_disc_ref_sec (v_index_sec);
                  ELSE
                     IF v_pay_disc_type_sec = r_c_disc_sec.disc_type_no
                     THEN
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_tot_disc_sec (v_index_pay_sec)
                           + v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     ELSE
                        v_index_pay_sec := v_index_pay_sec + 1;
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     END IF;
                  END IF;
               ELSE
                  v_cli_disc_ref_sec (v_index_sec) :=
                                               NVL (r_c_disc_sec.cli_disc, 0);
                  v_ref_disc_ref_sec (v_index_sec) :=
                                               NVL (r_c_disc_sec.ref_disc, 0);
                  v_disc_type_no_sec (v_index_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                  v_item_no_sec (v_index_sec) := p_item_no (v_index);
                  v_invoicedtl_no_sec (v_index_sec) :=
                                                    p_invoicedtl_no (v_index);

                  IF v_pay_disc_type_sec IS NULL
                  THEN
                     v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                     v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                     v_tot_disc_sec (v_index_pay_sec) :=
                          v_cli_disc_ref_sec (v_index_sec)
                        + v_ref_disc_ref_sec (v_index_sec);
                  ELSE
                     IF v_pay_disc_type_sec = r_c_disc_sec.disc_type_no
                     THEN
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_tot_disc_sec (v_index_pay_sec)
                           + v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     ELSE
                        v_index_pay_sec := v_index_pay_sec + 1;
                        v_pay_disc_type_sec := r_c_disc_sec.disc_type_no;
                        v_pay_disc_type_no_sec (v_index_pay_sec) :=
                                                    r_c_disc_sec.disc_type_no;
                        v_tot_disc_sec (v_index_pay_sec) :=
                             v_cli_disc_ref_sec (v_index_sec)
                           + v_ref_disc_ref_sec (v_index_sec);
                     END IF;
                  END IF;
               END IF;
            END LOOP;

            EXIT WHEN v_index >= NVL (p_index, 0);
            v_index := v_index + 1;
         END LOOP;
      END IF;

      OPEN c_bill_info;

      FETCH c_bill_info
       INTO r_c_bill_info;

      CLOSE c_bill_info;

      IF p_disc_time = 0
      THEN
         v_index := 1;

         IF v_pay_disc_type_ini IS NOT NULL
         THEN
            FOR i IN 1 .. v_index_pay_ini
            LOOP
               p_pay_mode (i) := NULL;
               p_coll_mode (i) := NULL;
               p_pay_type_no (i) := 8;
               p_pay_cqcc_others (i) := NULL;
               p_pay_bank_name (i) := NULL;
               p_amount (i) := v_tot_disc_ini (i);
               p_given_amt (i) := NULL;
               k_general.pd_genarate_id ('',
                                         'BILL_PAYMENT',
                                         'PAY_ID',
                                         p_company_no,
                                         v_pay_id
                                        );
               k_general.pd_genarate_no ('SEQ_PAY_NO',
                                         p_company_no,
                                         v_pay_no,
                                         'YY',
                                         10
                                        );

               INSERT INTO bill_payment
                           (pay_no, pay_id, pay_date, pay_datetime,
                            reg_no, invoice_no,
                            admission_no,
                            disc_type_no, pay_amt,
                            pay_type_no, bill_module_no,
                            ss_creator, ss_created_on, ss_created_session,
                            company_no
                           )
                    VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                            r_c_bill_info.reg_no, p_invoice_no,
                            r_c_bill_info.admission_no,
                            v_pay_disc_type_no_ini (i), p_amount (i),
                            p_pay_type_no (i), p_bill_module_no,
                            p_ss_creator, SYSDATE, p_ss_created_session,
                            p_company_no
                           );

               v_index := 1;

               LOOP
                  IF v_pay_disc_type_no_ini (i) =
                                                 v_disc_type_no_ini (v_index)
                  THEN
                     k_general.pd_genarate_no ('SEQ_PAYDTL_NO',
                                               p_company_no,
                                               v_paydtl_no,
                                               'YY',
                                               10
                                              );

                     INSERT INTO bill_paymentdtl
                                 (paydtl_no, pay_no, pay_date,
                                  pay_datetime, reg_no,
                                  invoice_no,
                                  invoicedtl_no,
                                  admission_no,
                                  item_no, bill_module_no,
                                  disc_type_no,
                                  cli_disc_ref,
                                  ref_disc_ref, ss_creator,
                                  ss_created_on, ss_created_session,
                                  company_no
                                 )
                          VALUES (v_paydtl_no, v_pay_no, TRUNC (SYSDATE),
                                  SYSDATE, r_c_bill_info.reg_no,
                                  p_invoice_no,
                                  v_invoicedtl_no_ini (v_index),
                                  r_c_bill_info.admission_no,
                                  v_item_no_ini (v_index), p_bill_module_no,
                                  v_disc_type_no_ini (v_index),
                                  v_cli_disc_ref_ini (v_index),
                                  v_ref_disc_ref_ini (v_index), p_ss_creator,
                                  SYSDATE, p_ss_created_session,
                                  p_company_no
                                 );
                  END IF;

                  EXIT WHEN v_index >= NVL (v_index_ini, 0);
                  v_index := v_index + 1;
               END LOOP;

               i_pay_no (i) := v_pay_no;
               i_pay_mode (i) := NULL;
               i_coll_mode (i) := NULL;
               i_pay_type_no (i) := 8;
               i_amount (i) := p_amount (i);
               i_given_amt (i) := NULL;
               k_ledger.pd_ledger
                          (p_reg_no                  => r_c_bill_info.reg_no,
                           p_invoice_no              => p_invoice_no,
                           p_invoice_id              => r_c_bill_info.invoice_id,
                           p_bill_module_no          => p_bill_module_no,
                           p_admission_no            => r_c_bill_info.admission_no,
                           p_admission_id            => r_c_bill_info.admission_id,
                           p_consultation_no         => r_c_bill_info.consultation_no,
                           p_pay_no                  => i_pay_no,
                           p_pay_mode                => i_pay_mode,
                           p_coll_mode               => i_coll_mode,
                           p_pay_type_no             => i_pay_type_no,
                           p_amount                  => i_amount,
                           p_given_amt               => i_given_amt,
                           p_index                   => 1,
                           p_disctype_no             => v_pay_disc_type_no_ini
                                                                           (i),
                           p_disc_auth_by            => NULL,
                           p_bed_no                  => r_c_bill_info.bed_no,
                           p_ss_creator              => p_ss_creator,
                           p_og_no                   => p_og_no,
                           p_company_no              => p_company_no,
                           p_ss_created_session      => p_ss_created_session,
                           p_error                   => p_error
                          );
            END LOOP;
         END IF;

         v_index := 1;

         IF v_pay_disc_type_sec IS NOT NULL
         THEN
            FOR i IN 1 .. v_index_pay_sec
            LOOP
               p_pay_mode (i) := NULL;
               p_coll_mode (i) := NULL;
               p_pay_type_no (i) := 9;
               p_pay_cqcc_others (i) := NULL;
               p_pay_bank_name (i) := NULL;
               p_amount (i) := v_tot_disc_sec (i);
               p_given_amt (i) := NULL;
               k_general.pd_genarate_id ('',
                                         'BILL_PAYMENT',
                                         'PAY_ID',
                                         p_company_no,
                                         v_pay_id
                                        );
               k_general.pd_genarate_no ('SEQ_PAY_NO',
                                         p_company_no,
                                         v_pay_no,
                                         'YY',
                                         10
                                        );

               INSERT INTO bill_payment
                           (pay_no, pay_id, pay_date, pay_datetime,
                            reg_no, invoice_no,
                            admission_no,
                            disc_type_no, pay_amt,
                            pay_type_no, bill_module_no,
                            ss_creator, ss_created_on, ss_created_session,
                            company_no
                           )
                    VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                            r_c_bill_info.reg_no, p_invoice_no,
                            r_c_bill_info.admission_no,
                            v_pay_disc_type_no_sec (i), p_amount (i),
                            p_pay_type_no (i), p_bill_module_no,
                            p_ss_creator, SYSDATE, p_ss_created_session,
                            p_company_no
                           );

               v_index := 1;

               LOOP
                  IF v_pay_disc_type_no_sec (i) =
                                                 v_disc_type_no_sec (v_index)
                  THEN
                     k_general.pd_genarate_no ('SEQ_PAYDTL_NO',
                                               p_company_no,
                                               v_paydtl_no,
                                               'YY',
                                               10
                                              );

                     INSERT INTO bill_paymentdtl
                                 (paydtl_no, pay_no, pay_date,
                                  pay_datetime, reg_no,
                                  invoice_no,
                                  invoicedtl_no,
                                  admission_no,
                                  item_no, bill_module_no,
                                  disc_type_no,
                                  cli_disc_ref,
                                  ref_disc_ref, ss_creator,
                                  ss_created_on, ss_created_session,
                                  company_no
                                 )
                          VALUES (v_paydtl_no, v_pay_no, TRUNC (SYSDATE),
                                  SYSDATE, r_c_bill_info.reg_no,
                                  p_invoice_no,
                                  v_invoicedtl_no_sec (v_index),
                                  r_c_bill_info.admission_no,
                                  v_item_no_sec (v_index), p_bill_module_no,
                                  v_disc_type_no_sec (v_index),
                                  v_cli_disc_ref_sec (v_index),
                                  v_ref_disc_ref_sec (v_index), p_ss_creator,
                                  SYSDATE, p_ss_created_session,
                                  p_company_no
                                 );
                  END IF;

                  EXIT WHEN v_index >= NVL (v_index_sec, 0);
                  v_index := v_index + 1;
               END LOOP;

               i_pay_no (i) := v_pay_no;
               i_pay_mode (i) := NULL;
               i_coll_mode (i) := NULL;
               i_pay_type_no (i) := 9;
               i_amount (i) := p_amount (i);
               i_given_amt (i) := NULL;
               k_ledger.pd_ledger
                          (p_reg_no                  => r_c_bill_info.reg_no,
                           p_invoice_no              => p_invoice_no,
                           p_invoice_id              => r_c_bill_info.invoice_id,
                           p_bill_module_no          => p_bill_module_no,
                           p_admission_no            => r_c_bill_info.admission_no,
                           p_admission_id            => r_c_bill_info.admission_id,
                           p_consultation_no         => r_c_bill_info.consultation_no,
                           p_pay_no                  => i_pay_no,
                           p_pay_mode                => i_pay_mode,
                           p_coll_mode               => i_coll_mode,
                           p_pay_type_no             => i_pay_type_no,
                           p_amount                  => i_amount,
                           p_given_amt               => i_given_amt,
                           p_index                   => 1,
                           p_disctype_no             => v_pay_disc_type_no_sec
                                                                           (i),
                           p_disc_auth_by            => NULL,
                           p_bed_no                  => r_c_bill_info.bed_no,
                           p_ss_creator              => p_ss_creator,
                           p_og_no                   => p_og_no,
                           p_company_no              => p_company_no,
                           p_ss_created_session      => p_ss_created_session,
                           p_error                   => p_error
                          );
            END LOOP;
         END IF;
      ELSIF p_disc_time = 1
      THEN
         v_index := 1;

         IF v_pay_disc_type_ini IS NOT NULL
         THEN
            FOR i IN 1 .. v_index_pay_ini
            LOOP
               p_pay_mode (i) := NULL;
               p_coll_mode (i) := NULL;
               p_pay_type_no (i) := 8;
               p_pay_cqcc_others (i) := NULL;
               p_pay_bank_name (i) := NULL;
               p_amount (i) := v_tot_disc_ini (i);
               p_given_amt (i) := NULL;
               k_general.pd_genarate_id ('',
                                         'BILL_PAYMENT',
                                         'PAY_ID',
                                         p_company_no,
                                         v_pay_id
                                        );
               k_general.pd_genarate_no ('SEQ_PAY_NO',
                                         p_company_no,
                                         v_pay_no,
                                         'YY',
                                         10
                                        );

               INSERT INTO bill_payment
                           (pay_no, pay_id, pay_date, pay_datetime,
                            reg_no, invoice_no,
                            admission_no,
                            disc_type_no, pay_amt,
                            pay_type_no, bill_module_no,
                            ss_creator, ss_created_on, ss_created_session,
                            company_no
                           )
                    VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                            r_c_bill_info.reg_no, p_invoice_no,
                            r_c_bill_info.admission_no,
                            v_pay_disc_type_no_ini (i), p_amount (i),
                            p_pay_type_no (i), p_bill_module_no,
                            p_ss_creator, SYSDATE, p_ss_created_session,
                            p_company_no
                           );

               v_index := 1;

               LOOP
                  IF v_pay_disc_type_no_ini (i) =
                                                 v_disc_type_no_ini (v_index)
                  THEN
                     k_general.pd_genarate_no ('SEQ_PAYDTL_NO',
                                               p_company_no,
                                               v_paydtl_no,
                                               'YY',
                                               10
                                              );

                     INSERT INTO bill_paymentdtl
                                 (paydtl_no, pay_no, pay_date,
                                  pay_datetime, reg_no,
                                  invoice_no,
                                  invoicedtl_no,
                                  admission_no,
                                  item_no, bill_module_no,
                                  disc_type_no,
                                  cli_disc_ref,
                                  ref_disc_ref, ss_creator,
                                  ss_created_on, ss_created_session,
                                  company_no
                                 )
                          VALUES (v_paydtl_no, v_pay_no, TRUNC (SYSDATE),
                                  SYSDATE, r_c_bill_info.reg_no,
                                  p_invoice_no,
                                  v_invoicedtl_no_ini (v_index),
                                  r_c_bill_info.admission_no,
                                  v_item_no_ini (v_index), p_bill_module_no,
                                  v_disc_type_no_ini (v_index),
                                  v_cli_disc_ref_ini (v_index),
                                  v_ref_disc_ref_ini (v_index), p_ss_creator,
                                  SYSDATE, p_ss_created_session,
                                  p_company_no
                                 );
                  END IF;

                  EXIT WHEN v_index >= NVL (v_index_ini, 0);
                  v_index := v_index + 1;
               END LOOP;

               i_pay_no (i) := v_pay_no;
               i_pay_mode (i) := NULL;
               i_coll_mode (i) := NULL;
               i_pay_type_no (i) := 8;
               i_amount (i) := p_amount (i);
               i_given_amt (i) := NULL;
               k_ledger.pd_ledger
                          (p_reg_no                  => r_c_bill_info.reg_no,
                           p_invoice_no              => p_invoice_no,
                           p_invoice_id              => r_c_bill_info.invoice_id,
                           p_bill_module_no          => p_bill_module_no,
                           p_admission_no            => r_c_bill_info.admission_no,
                           p_admission_id            => r_c_bill_info.admission_id,
                           p_consultation_no         => r_c_bill_info.consultation_no,
                           p_pay_no                  => i_pay_no,
                           p_pay_mode                => i_pay_mode,
                           p_coll_mode               => i_coll_mode,
                           p_pay_type_no             => i_pay_type_no,
                           p_amount                  => i_amount,
                           p_given_amt               => i_given_amt,
                           p_index                   => 1,
                           p_disctype_no             => v_pay_disc_type_no_ini
                                                                           (i),
                           p_disc_auth_by            => NULL,
                           p_bed_no                  => r_c_bill_info.bed_no,
                           p_ss_creator              => p_ss_creator,
                           p_og_no                   => p_og_no,
                           p_company_no              => p_company_no,
                           p_ss_created_session      => p_ss_created_session,
                           p_error                   => p_error
                          );
            END LOOP;
         END IF;
      ELSIF p_disc_time = 2
      THEN
         v_index := 1;

         IF v_pay_disc_type_sec IS NOT NULL
         THEN
            FOR i IN 1 .. v_index_pay_sec
            LOOP
               p_pay_mode (i) := NULL;
               p_coll_mode (i) := NULL;
               p_pay_type_no (i) := 9;
               p_pay_cqcc_others (i) := NULL;
               p_pay_bank_name (i) := NULL;
               p_amount (i) := v_tot_disc_sec (i);
               p_given_amt (i) := NULL;
               k_general.pd_genarate_id ('',
                                         'BILL_PAYMENT',
                                         'PAY_ID',
                                         p_company_no,
                                         v_pay_id
                                        );
               k_general.pd_genarate_no ('SEQ_PAY_NO',
                                         p_company_no,
                                         v_pay_no,
                                         'YY',
                                         10
                                        );

               INSERT INTO bill_payment
                           (pay_no, pay_id, pay_date, pay_datetime,
                            reg_no, invoice_no,
                            admission_no,
                            disc_type_no, pay_amt,
                            pay_type_no, bill_module_no,
                            ss_creator, ss_created_on, ss_created_session,
                            company_no
                           )
                    VALUES (v_pay_no, v_pay_id, TRUNC (SYSDATE), SYSDATE,
                            r_c_bill_info.reg_no, p_invoice_no,
                            r_c_bill_info.admission_no,
                            v_pay_disc_type_no_sec (i), p_amount (i),
                            p_pay_type_no (i), p_bill_module_no,
                            p_ss_creator, SYSDATE, p_ss_created_session,
                            p_company_no
                           );

               v_index := 1;

               LOOP
                  IF v_pay_disc_type_no_sec (i) =
                                                 v_disc_type_no_sec (v_index)
                  THEN
                     k_general.pd_genarate_no ('SEQ_PAYDTL_NO',
                                               p_company_no,
                                               v_paydtl_no,
                                               'YY',
                                               10
                                              );

                     INSERT INTO bill_paymentdtl
                                 (paydtl_no, pay_no, pay_date,
                                  pay_datetime, reg_no,
                                  invoice_no,
                                  invoicedtl_no,
                                  admission_no,
                                  item_no, bill_module_no,
                                  disc_type_no,
                                  cli_disc_ref,
                                  ref_disc_ref, ss_creator,
                                  ss_created_on, ss_created_session,
                                  company_no
                                 )
                          VALUES (v_paydtl_no, v_pay_no, TRUNC (SYSDATE),
                                  SYSDATE, r_c_bill_info.reg_no,
                                  p_invoice_no,
                                  v_invoicedtl_no_sec (v_index),
                                  r_c_bill_info.admission_no,
                                  v_item_no_sec (v_index), p_bill_module_no,
                                  v_disc_type_no_sec (v_index),
                                  v_cli_disc_ref_sec (v_index),
                                  v_ref_disc_ref_sec (v_index), p_ss_creator,
                                  SYSDATE, p_ss_created_session,
                                  p_company_no
                                 );
                  END IF;

                  EXIT WHEN v_index >= NVL (v_index_sec, 0);
                  v_index := v_index + 1;
               END LOOP;

               i_pay_no (i) := v_pay_no;
               i_pay_mode (i) := NULL;
               i_coll_mode (i) := NULL;
               i_pay_type_no (i) := 9;
               i_amount (i) := p_amount (i);
               i_given_amt (i) := NULL;
               k_ledger.pd_ledger
                          (p_reg_no                  => r_c_bill_info.reg_no,
                           p_invoice_no              => p_invoice_no,
                           p_invoice_id              => r_c_bill_info.invoice_id,
                           p_bill_module_no          => p_bill_module_no,
                           p_admission_no            => r_c_bill_info.admission_no,
                           p_admission_id            => r_c_bill_info.admission_id,
                           p_consultation_no         => r_c_bill_info.consultation_no,
                           p_pay_no                  => i_pay_no,
                           p_pay_mode                => i_pay_mode,
                           p_coll_mode               => i_coll_mode,
                           p_pay_type_no             => i_pay_type_no,
                           p_amount                  => i_amount,
                           p_given_amt               => i_given_amt,
                           p_index                   => 1,
                           p_disctype_no             => v_pay_disc_type_no_sec
                                                                           (i),
                           p_disc_auth_by            => NULL,
                           p_bed_no                  => r_c_bill_info.bed_no,
                           p_ss_creator              => p_ss_creator,
                           p_og_no                   => p_og_no,
                           p_company_no              => p_company_no,
                           p_ss_created_session      => p_ss_created_session,
                           p_error                   => p_error
                          );
            END LOOP;
         END IF;
      END IF;

      IF p_error IS NULL
      THEN
         COMMIT;
      ELSE
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
   END pd_item_disc_cancel_web;

    PROCEDURE pd_item_cancel_web (
      p_invoice_no           IN       NUMBER,
      p_invoice_id           IN       VARCHAR2,
      p_reg_no               IN       NUMBER,
      p_admission_no         IN       NUMBER DEFAULT NULL,
      p_admission_id         IN       VARCHAR2 DEFAULT NULL,
      p_bed_no               IN       NUMBER DEFAULT NULL,
      p_consultation_no      IN       NUMBER DEFAULT NULL,
      p_bill_module_no       IN       NUMBER,
      p_invoicedtl_no        IN       k_opd.arlist_numb,
      p_item_no              IN       k_opd.arlist_numb,
      p_item_qty             IN       k_opd.arlist_numb,
      p_itemtype_no          IN       k_opd.arlist_numb,
      p_cancel_reason        IN       k_opd.arlist_varc,
      p_index                IN       NUMBER,
      p_ss_creator           IN       NUMBER,
      p_og_no                IN       NUMBER,
      p_company_no           IN       NUMBER,
      p_ss_created_session   IN       NUMBER,
      p_error                OUT      VARCHAR2
   )
   IS
      CURSOR c_cancel (p_invdtl_no NUMBER)
      IS
         SELECT        item_no, item_name, item_qty, cancel_qty, cancel_flag,
                       item_rate, NVL (item_vat, 0) item_vat,
                       NVL (urgent_fee, 0) urgent_fee,
                       NVL (service_charge, 0) service_charge,
                       item_qty - NVL (cancel_qty, 0) act_qty
                  FROM bill_invoicedtl
                 WHERE invoicedtl_no = p_invdtl_no
         FOR UPDATE OF cancel_flag, cancel_qty WAIT 60;

      r_c_cancel        c_cancel%ROWTYPE;
      v_index           NUMBER               := 1;
      v_addcancel_no    NUMBER;
      v_disc_index      NUMBER               := 0;
      i_pay_no          k_ledger.arlist_numb;
      i_pay_mode        k_ledger.arlist_numb;
      i_coll_mode       k_ledger.arlist_numb;
      i_pay_type_no     k_ledger.arlist_numb;
      i_amount          k_ledger.arlist_numb;
      i_given_amt       k_ledger.arlist_numb;
      v_item_total      NUMBER               := 0;
      v_vat_total       NUMBER               := 0;
      v_urg_fee_total   NUMBER               := 0;
      v_ser_cha_total   NUMBER               := 0;

      CURSOR c_disc (p_invoicedtl NUMBER, p_item NUMBER)
      IS
         SELECT COUNT (1)
           FROM bill_paymentdtl
          WHERE invoice_no = p_invoice_no
            AND invoicedtl_no = p_invoicedtl
            AND item_no = p_item;

      v_exist           NUMBER;

      CURSOR c_disc_return (p_invoicedtl NUMBER, p_item NUMBER)
      IS
         SELECT SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0)) cli_disc,
                SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0)) ref_disc
           FROM bill_paymentdtl
          WHERE invoice_no = p_invoice_no
            AND invoicedtl_no = p_invoicedtl
            AND item_no = p_item
         HAVING SUM (NVL (cli_disc_amt, 0) - NVL (cli_disc_ref, 0)) > 0
             OR SUM (NVL (ref_disc_amt, 0) - NVL (ref_disc_ref, 0)) > 0;

      i_invoicedtl_no   k_opd.arlist_numb;
      i_item_no         k_opd.arlist_numb;
      i_item_qty        k_opd.arlist_numb;
      v_error           VARCHAR2 (4000);
   BEGIN
      LOOP
         OPEN c_disc (p_invoicedtl_no (v_index), p_item_no (v_index));

         FETCH c_disc
          INTO v_exist;

         CLOSE c_disc;

         IF v_exist >= 1
         THEN
            FOR j IN c_disc_return (p_invoicedtl_no (v_index),
                                    p_item_no (v_index)
                                   )
            LOOP
               v_disc_index := v_disc_index + 1;
               i_invoicedtl_no (v_disc_index) := p_invoicedtl_no (v_index);
               i_item_no (v_disc_index) := p_item_no (v_index);
               i_item_qty (v_disc_index) := p_item_qty (v_index);
            END LOOP;
         END IF;

         EXIT WHEN v_index >= NVL (p_index, 0);
         v_index := v_index + 1;
      END LOOP;

      IF v_disc_index > 0
      THEN
         pd_item_disc_cancel_web (p_invoice_no              => p_invoice_no,
                              p_bill_module_no          => p_bill_module_no,
                              p_disc_time               => 0,
                              p_invoicedtl_no           => i_invoicedtl_no,
                              p_item_no                 => i_item_no,
                              p_item_qty                => i_item_qty,
                              p_index                   => v_disc_index,
                              p_ss_creator              => p_ss_creator,
                              p_og_no                   => p_og_no,
                              p_company_no              => p_company_no,
                              p_ss_created_session      => p_ss_created_session,
                              p_error                   => v_error
                             );

         IF v_error IS NOT NULL
         THEN
            p_error := v_error;
            ROLLBACK;
            RETURN;
         END IF;
      END IF;

      v_index := 1;

      LOOP
         OPEN c_cancel (p_invoicedtl_no (v_index));

         FETCH c_cancel
          INTO r_c_cancel;

         IF r_c_cancel.cancel_flag = 1
         THEN
            p_error :=
                  'Others user already cancelled '
               || r_c_cancel.item_name
               || '. Please check.';

            CLOSE c_cancel;

            ROLLBACK;
            RETURN;
         END IF;

         IF r_c_cancel.act_qty < p_item_qty (v_index)
         THEN
            p_error :=
                  'Others user already cancelled some item of '
               || r_c_cancel.item_name
               || '. Please check.';

            CLOSE c_cancel;

            ROLLBACK;
            RETURN;
         END IF;

         v_item_total :=
                    v_item_total + r_c_cancel.item_rate * p_item_qty (v_index);
         v_vat_total :=
                      v_vat_total + r_c_cancel.item_vat * p_item_qty (v_index);
         v_urg_fee_total :=
                v_urg_fee_total + r_c_cancel.urgent_fee * p_item_qty (v_index);
         v_ser_cha_total :=
            v_ser_cha_total + r_c_cancel.service_charge * p_item_qty (v_index);

         IF r_c_cancel.item_qty =
                          NVL (r_c_cancel.cancel_qty, 0)
                          + p_item_qty (v_index)
         THEN
            UPDATE bill_invoicedtl
               SET cancel_flag = 1,
                   cancel_qty = item_qty,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = SYSDATE,
                   ss_modified_session = p_ss_created_session
             WHERE invoicedtl_no = p_invoicedtl_no (v_index);

            UPDATE bill_ledgerdtl
               SET cancel_flag = 1,
                   cancel_qty = item_qty,
                   ss_modifier = p_ss_creator,
                   ss_modified_on = SYSDATE,
                   ss_modified_session = p_ss_created_session
             WHERE invoicedtl_no = p_invoicedtl_no (v_index);
         ELSE
            UPDATE bill_invoicedtl
               SET cancel_qty = NVL (cancel_qty, 0) + p_item_qty (v_index),
                   ss_modifier = p_ss_creator,
                   ss_modified_on = SYSDATE,
                   ss_modified_session = p_ss_created_session
             WHERE invoicedtl_no = p_invoicedtl_no (v_index);

            UPDATE bill_ledgerdtl
               SET cancel_qty = NVL (cancel_qty, 0) + p_item_qty (v_index),
                   ss_modifier = p_ss_creator,
                   ss_modified_on = SYSDATE,
                   ss_modified_session = p_ss_created_session
             WHERE invoicedtl_no = p_invoicedtl_no (v_index);
         END IF;

         k_general.pd_genarate_no ('SEQ_ADDCANCEL_NO',
                                   p_company_no,
                                   v_addcancel_no,
                                   'YY',
                                   10
                                  );

         INSERT INTO bill_ledger_addcancel
                     (addcancel_no, invoice_no,
                      invoicedtl_no, item_no,
                      item_qty, process_type, process_by, process_date,
                      process_datetime, process_reason, bill_module_no,
                      ss_creator, ss_created_on, ss_created_session,
                      company_no
                     )
              VALUES (v_addcancel_no, p_invoice_no,
                      p_invoicedtl_no (v_index), p_item_no (v_index),
                      p_item_qty (v_index), 0, p_ss_creator, TRUNC (SYSDATE),
                      SYSDATE, p_cancel_reason (v_index), p_bill_module_no,
                      p_ss_creator, SYSDATE, p_ss_created_session,
                      p_company_no
                     );

         CLOSE c_cancel;

         EXIT WHEN v_index >= NVL (p_index, 0);
         v_index := v_index + 1;
      END LOOP;

      v_index := 0;

      IF v_item_total > 0
      THEN
         v_index := v_index + 1;
         i_pay_no (v_index) := NULL;
         i_pay_mode (v_index) := NULL;
         i_coll_mode (v_index) := NULL;
         i_pay_type_no (v_index) := 2;
         i_amount (v_index) := v_item_total;
         i_given_amt (v_index) := NULL;
      END IF;

      IF v_vat_total > 0
      THEN
         v_index := v_index + 1;
         i_pay_no (v_index) := NULL;
         i_pay_mode (v_index) := NULL;
         i_coll_mode (v_index) := NULL;
         i_pay_type_no (v_index) := 11;
         i_amount (v_index) := v_vat_total;
         i_given_amt (v_index) := NULL;
      END IF;

      IF v_urg_fee_total > 0
      THEN
         v_index := v_index + 1;
         i_pay_no (v_index) := NULL;
         i_pay_mode (v_index) := NULL;
         i_coll_mode (v_index) := NULL;
         i_pay_type_no (v_index) := 13;
         i_amount (v_index) := v_urg_fee_total;
         i_given_amt (v_index) := NULL;
      END IF;

      IF v_ser_cha_total > 0
      THEN
         v_index := v_index + 1;
         i_pay_no (v_index) := NULL;
         i_pay_mode (v_index) := NULL;
         i_coll_mode (v_index) := NULL;
         i_pay_type_no (v_index) := 15;
         i_amount (v_index) := v_ser_cha_total;
         i_given_amt (v_index) := NULL;
      END IF;

      IF    v_item_total > 0
         OR v_vat_total > 0
         OR v_urg_fee_total > 0
         OR v_ser_cha_total > 0
      THEN
         k_ledger.pd_ledger (p_reg_no                  => p_reg_no,
                             p_invoice_no              => p_invoice_no,
                             p_invoice_id              => p_invoice_id,
                             p_bill_module_no          => p_bill_module_no,
                             p_admission_no            => p_admission_no,
                             p_admission_id            => p_admission_id,
                             p_consultation_no         => p_consultation_no,
                             p_pay_no                  => i_pay_no,
                             p_pay_mode                => i_pay_mode,
                             p_coll_mode               => i_coll_mode,
                             p_pay_type_no             => i_pay_type_no,
                             p_amount                  => i_amount,
                             p_given_amt               => i_given_amt,
                             p_index                   => v_index,
                             p_disctype_no             => NULL,
                             p_disc_auth_by            => NULL,
                             p_bed_no                  => p_bed_no,
                             p_ss_creator              => p_ss_creator,
                             p_og_no                   => p_og_no,
                             p_company_no              => p_company_no,
                             p_ss_created_session      => p_ss_created_session,
                             p_error                   => p_error
                            );
      END IF;

      IF p_error IS NULL AND v_error IS NULL
      THEN
         COMMIT;
      ELSE
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
         ROLLBACK;
   END pd_item_cancel_web;
   
   PROCEDURE pd_invoice_cancel_web (
      p_invoice_no           IN       NUMBER,
      p_bill_module_no       IN       NUMBER,
      p_item_no              IN       k_opd.arlist_numb,
      p_invoicedtl_no        IN       k_opd.arlist_numb,
      p_item_qty             IN       k_opd.arlist_numb,
      p_itemtype_no          IN       k_opd.arlist_numb,
      p_cancel_reason        IN       k_opd.arlist_varc,
      p_index                IN       NUMBER,
      p_ss_creator           IN       NUMBER,
      p_og_no                IN       NUMBER,
      p_company_no           IN       NUMBER,
      p_ss_created_session   IN       NUMBER,
      p_error                OUT      VARCHAR2
   )
   IS
      v_index             NUMBER                := 1;
      i_invoicedtl_no     k_opd.arlist_numb;
      i_item_no           k_opd.arlist_numb;
      i_item_qty          k_opd.arlist_numb;
      i_itemtype_no       k_opd.arlist_numb;
      i_cancel_reason     k_opd.arlist_varc;

      CURSOR c_bill_info
      IS
         SELECT        o.invoice_id invoice_id, o.reg_no, o.admission_no,
                       o.admission_id, o.consultation_no,
                       CASE
                          WHEN admission_no IS NOT NULL
                             THEN k_ipd.fd_current_bed_no
                                                         (admission_no)
                          ELSE NULL
                       END bed_no,
                       o.invoice_cancel_flag, v.total_pay_amt
                  FROM bill_invoice o, BILL_INVOICE_STATUS_V v
                 WHERE o.invoice_no = v.invoice_no
                   AND o.invoice_no = p_invoice_no
         FOR UPDATE OF invoice_cancel_flag WAIT 60;

      r_c_bill_info       c_bill_info%ROWTYPE;
      i_pay_mode          k_opd.arlist_numb;
      i_coll_mode         k_opd.arlist_numb;
      i_pay_type_no       k_opd.arlist_numb;
      i_pay_cqcc_others   k_opd.arlist_varc;
      i_pay_bank_name     k_opd.arlist_varc;
      i_pay_amt           k_opd.arlist_numb;
      i_given_amt         k_opd.arlist_numb;
   BEGIN
      OPEN c_bill_info;

      FETCH c_bill_info
       INTO r_c_bill_info;

      IF r_c_bill_info.invoice_cancel_flag = 1
      THEN
         p_error :=
                   'Other user already cancelled this invoice. Please check.';

         CLOSE c_bill_info;

         RETURN;
      END IF;

      LOOP
         i_invoicedtl_no (v_index) := p_invoicedtl_no (v_index);
         i_item_no (v_index) := p_item_no (v_index);
         i_item_qty (v_index) := p_item_qty (v_index);
         i_itemtype_no (v_index) := p_itemtype_no (v_index);
         i_cancel_reason (v_index) := p_cancel_reason (v_index);
         EXIT WHEN v_index >= NVL (p_index, 0);
         v_index := v_index + 1;
      END LOOP;

      pd_item_cancel_web (p_invoice_no              => p_invoice_no,
                      p_invoice_id              => r_c_bill_info.invoice_id,
                      p_reg_no                  => r_c_bill_info.reg_no,
                      p_admission_no            => r_c_bill_info.admission_no,
                      p_admission_id            => r_c_bill_info.admission_id,
                      p_bed_no                  => r_c_bill_info.bed_no,
                      p_consultation_no         => r_c_bill_info.consultation_no,
                      p_bill_module_no          => p_bill_module_no,
                      p_invoicedtl_no           => i_invoicedtl_no,
                      p_item_no                 => i_item_no,
                      p_item_qty                => i_item_qty,
                      p_itemtype_no             => i_itemtype_no,
                      p_cancel_reason           => i_cancel_reason,
                      p_index                   => v_index,
                      p_ss_creator              => p_ss_creator,
                      p_og_no                   => p_og_no,
                      p_company_no              => p_company_no,
                      p_ss_created_session      => p_ss_created_session,
                      p_error                   => p_error
                     );
      i_pay_mode (1) := 1;
      i_coll_mode (1) := 1;
      i_pay_type_no (1) := 5;
      i_pay_cqcc_others (1) := NULL;
      i_pay_bank_name (1) := NULL;
      i_pay_amt (1) := r_c_bill_info.total_pay_amt;
      i_given_amt (1) := NULL;
      pd_refund (p_invoice_no              => p_invoice_no,
                 p_invoice_id              => r_c_bill_info.invoice_id,
                 p_reg_no                  => r_c_bill_info.reg_no,
                 p_admission_no            => r_c_bill_info.admission_no,
                 p_admission_id            => r_c_bill_info.admission_id,
                 p_bed_no                  => r_c_bill_info.bed_no,
                 p_consultation_no         => r_c_bill_info.consultation_no,
                 p_bill_module_no          => p_bill_module_no,
                 p_pay_mode                => i_pay_mode,
                 p_coll_mode               => i_coll_mode,
                 p_pay_type_no             => i_pay_type_no,
                 p_pay_cqcc_others         => i_pay_cqcc_others,
                 p_pay_bank_name           => i_pay_bank_name,
                 p_pay_amt                 => i_pay_amt,
                 p_given_amt               => i_given_amt,
                 p_pay_index               => 1,
                 p_pay_remarks             => NULL,
                 p_ss_creator              => p_ss_creator,
                 p_og_no                   => p_og_no,
                 p_company_no              => p_company_no,
                 p_ss_created_session      => p_ss_created_session,
                 p_error                   => p_error
                );

      UPDATE bill_invoice
         SET invoice_cancel_flag = 1,
             invoice_cancel_remark = p_cancel_reason (1),
             ss_modifier = p_ss_creator,
             ss_modified_on = SYSDATE,
             ss_modified_session = p_ss_created_session
       WHERE invoice_no = p_invoice_no;

      UPDATE bill_ledgermst
         SET invoice_cancel_flag = 1,
             ss_modifier = p_ss_creator,
             ss_modified_on = SYSDATE,
             ss_modified_session = p_ss_created_session
       WHERE invoice_no = p_invoice_no;

      UPDATE opd_consultation
         SET cancel_flag = 1,
             cancel_reason = p_cancel_reason (1),
             ss_modifier = p_ss_creator,
             ss_modified_on = SYSDATE,
             ss_modified_session = p_ss_created_session
       WHERE opd_consultation_no = r_c_bill_info.consultation_no;

      CLOSE c_bill_info;

      IF p_error IS NULL
      THEN
         COMMIT;
      ELSE
         ROLLBACK;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         p_error := SQLERRM;
   END pd_invoice_cancel_web;
   
procedure pd_invoice_web (
                      p_reg_no                    in       number default null,
                      p_hospital_number           in       varchar2 default null,
                      p_pat_type_no               in       number default null,
                      p_admission_no              in       number default null,
                      p_admission_id              in       varchar2 default null,
                      p_consultation_no           in       number default null,
                      p_bed_no                    in       number default null,
                      p_salutation                in       varchar2,
                      p_fname                     in       varchar2,
                      p_lname                     in       varchar2,
                      p_gender                    in       varchar2,
                      p_m_status                  in       varchar2,
                      p_age_dd                    in       number,
                      p_age_mm                    in       number,
                      p_age_yy                    in       number,
                      p_phone_mobile              in       varchar2,
                      p_dob                       in       date default null,
                      p_address                   in       varchar2 default null,
                      p_blood_group               in       varchar2 default null,
                      p_religion                  in       varchar2 default null,
                      p_email                     in       varchar2 default null,
                      p_national_id               in       varchar2 default null,
                      p_ref_doc_no                in       number default null,
                      p_remarks                   in       varchar2 default null,
                      p_delivery_date             in       date default null,
                      p_bill_module_no            in       number,
                      p_item_no                   in       k_opd.arlist_numb,
                      p_item_name                 in       k_opd.arlist_varc,
                      p_item_qty                  in       k_opd.arlist_numb,
                      p_item_rate                 in       k_opd.arlist_numb,
                      p_item_vat                  in       k_opd.arlist_numb,
                      p_urgent_fee                in       k_opd.arlist_numb,
                      p_service_charge            in       k_opd.arlist_numb,
                      p_itemtype_no               in       k_opd.arlist_numb,
                      p_par_itemtype_no           in       k_opd.arlist_numb,
                      p_bu_no                     in       k_opd.arlist_numb,
                      p_delivery_status_no        in       k_opd.arlist_numb,
                      p_package_item_flag         in       k_opd.arlist_numb,
                      p_cli_disc_amt              in       k_opd.arlist_numb,
                      p_item_index                in       number,
                      p_cor_client_no             in       number default null,
                      p_cor_client_emp_id         in       varchar2 default null,
                      p_emp_no                    in       number default null,
                      p_relation_no               in       number default null,
                      p_card_no                   in       number default null,
                      p_pay_mode                  in       k_opd.arlist_numb,
                      p_coll_mode                 in       k_opd.arlist_numb,
                      p_pay_type_no               in       k_opd.arlist_numb,
                      p_pay_cqcc_others           in       k_opd.arlist_varc,
                      p_pay_bank_name             in       k_opd.arlist_varc,
                      p_pay_amt                   in       k_opd.arlist_numb,
                      p_given_amt                 in       k_opd.arlist_numb,
                      p_pay_index                 in       number   default 0,
                      p_disc_amount               in       number   default null,
                      p_disctype_no               in       number   default null,  
                      p_disc_auth_by              in       number   default null,
                      p_disc_remarks              in       varchar2 default null,
                      p_ss_creator                in       number,
                      p_og_no                     in       number,
                      p_company_no                in       number,
                      p_ss_created_session        in       number,
                      p_invoice_no                out      number,
                      p_invoice_id                out      varchar2,
                      p_error                     out      varchar2
                     )
as

    cursor c_config
    is
    select hn_prifix, opd_invoice_prifix, invoince_method
    from opd_config
    where company_no = p_company_no;
    r_c_config  c_config%rowtype;
    
    v_reg_no            number;
    v_hospital_number   varchar2(50);
    v_bill_index        number := 1;
    v_pay_index         number := 1;
    v_invoicedtl_no     number;
    v_lab_exist         number := 0;
    v_pay_no            number;
    v_pay_id            varchar2(50);
    v_paydtl_no         number;
    
    i_invoicedtl_no         k_ledger.arlist_numb;
    i_item_no               k_ledger.arlist_numb;
    i_item_name             k_ledger.arlist_varc;
    i_item_qty              k_ledger.arlist_numb;
    i_item_rate             k_ledger.arlist_numb;
    i_item_vat              k_ledger.arlist_numb;
    i_urgent_fee            k_ledger.arlist_numb;
    i_service_charge        k_ledger.arlist_numb;
    i_itemtype_no           k_ledger.arlist_numb;
    i_par_itemtype_no       k_ledger.arlist_numb;
    i_bu_no                 k_ledger.arlist_numb;
    i_delivery_status_no    k_ledger.arlist_numb;
    i_package_item_flag     k_ledger.arlist_numb;
    i_pur_rate              k_ledger.arlist_numb;  
    
    i_pay_no                k_ledger.arlist_numb;
    i_pay_mode              k_ledger.arlist_numb;
    i_coll_mode             k_ledger.arlist_numb;
    i_pay_type_no           k_ledger.arlist_numb;
    i_amount                k_ledger.arlist_numb;
    i_given_amt             k_ledger.arlist_numb;
    
   
    
begin
    
    open c_config;
    fetch c_config into r_c_config;
    close c_config;
    
    if p_reg_no is null then
    
        k_general.pd_genarate_id (r_c_config.hn_prifix, 'OPD_REGISTRATION', 'HOSPITAL_NUMBER', p_company_no, v_hospital_number);
        k_general.pd_genarate_no ('SEQ_REG_NO', p_company_no, v_reg_no, 'YY', 10);
        
        insert into opd_registration (reg_no, hospital_number, reg_date, salutation, 
                                      fname, lname, gender, m_status, 
                                      age_dd, age_mm, age_yy, dob, 
                                      blood_group, religion, phone_mobile, email, 
                                      address, national_id, pat_type_no, reg_point, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
                                      
        values (v_reg_no, v_hospital_number, sysdate, p_salutation, 
                p_fname, p_lname, p_gender, p_m_status, 
                p_age_dd, p_age_mm, p_age_yy, p_dob, 
                p_blood_group, p_religion, p_phone_mobile, p_email, 
                p_address, p_national_id, p_pat_type_no, 5, p_ss_creator, 
                sysdate, p_ss_created_session, p_company_no);
    
    else
        v_reg_no := p_reg_no;        
    end if;
    
    k_general.pd_genarate_no ('SEQ_INVOICE_NO', p_company_no, p_invoice_no,'YY', 10);
    
    if r_c_config.invoince_method is null then
        
        k_general.pd_genarate_id (r_c_config.opd_invoice_prifix, 'OPD_INVOICE', 'OPD_INVOICE_ID', p_company_no, p_invoice_id);
            
    else    
        
        execute immediate 'SELECT '||r_c_config.invoince_method|| ' FROM SYS.DUAL' into p_invoice_id;
            
    end if;
    
    insert into opd_invoice (opd_invoice_no, opd_invoice_id, bill_module_no, reg_no, 
                              admission_no, admission_id, consultation_no, invoice_date, 
                              invoice_datetime, doctor_no, remarks,bu_no, 
                              cor_client_no,  cor_client_card_no, emp_no, relation_no, 
                              pat_type_no, ss_creator, ss_created_on, 
                              ss_created_session, company_no, card_no)
    values (p_invoice_no, p_invoice_id, p_bill_module_no, v_reg_no,
            p_admission_no, p_admission_id, p_consultation_no, trunc(sysdate),
            sysdate, p_ref_doc_no, p_remarks,p_bu_no (1),
            p_cor_client_no, p_cor_client_emp_id, p_emp_no, p_relation_no, 
            p_pat_type_no, p_ss_creator, sysdate, 
            p_ss_created_session, p_company_no, p_card_no);
    
    loop
    
        k_general.pd_genarate_no ('SEQ_INVOICEDTL_NO', p_company_no, v_invoicedtl_no,'YY',10);
          
        insert into opd_invoicedtl(opd_invoicedtl_no, opd_invoice_no, item_no, item_name, 
                                    itemtype_no, item_qty, item_rate, item_vat, 
                                    urgent_fee, service_charge, package_item_flag, bu_no, 
                                    ss_creator, ss_created_on, ss_created_session, company_no)
        values(v_invoicedtl_no, p_invoice_no, p_item_no (v_bill_index), p_item_name (v_bill_index), 
               p_itemtype_no (v_bill_index), p_item_qty (v_bill_index), p_item_rate (v_bill_index), p_item_vat (v_bill_index), 
               p_urgent_fee (v_bill_index), p_service_charge (v_bill_index), p_package_item_flag (v_bill_index), p_bu_no (v_bill_index), 
               p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        i_invoicedtl_no (v_bill_index) := v_invoicedtl_no;
        i_item_no            (v_bill_index) := p_item_no (v_bill_index);
        i_item_name          (v_bill_index) := p_item_name (v_bill_index);
        i_item_qty           (v_bill_index) := p_item_qty (v_bill_index);
        i_item_rate          (v_bill_index) := p_item_rate (v_bill_index);
        i_item_vat           (v_bill_index) := p_item_vat (v_bill_index);
        i_urgent_fee         (v_bill_index) := p_urgent_fee (v_bill_index);
        i_service_charge     (v_bill_index) := p_service_charge (v_bill_index);
        i_itemtype_no        (v_bill_index) := p_itemtype_no (v_bill_index);
        i_par_itemtype_no    (v_bill_index) := p_par_itemtype_no (v_bill_index);
        i_bu_no              (v_bill_index) := p_bu_no (v_bill_index);
        i_delivery_status_no (v_bill_index) := p_delivery_status_no (v_bill_index);
        i_package_item_flag  (v_bill_index) := p_package_item_flag (v_bill_index);
        i_pur_rate           (v_bill_index) := null;
                                           
    exit when v_bill_index >= nvl (p_item_index, 0);
        v_bill_index := v_bill_index + 1; 
    end loop;
    
                                  
    k_ledger.pd_ledger_bill(p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_ref_doc_no                => p_ref_doc_no,
                            p_second_ref_doc_no         => null, 
                            p_doctor_no                 => p_ref_doc_no,
                            p_invoicedtl_no             => i_invoicedtl_no,                    
                            p_item_no                   => i_item_no,
                            p_item_name                 => i_item_name,
                            p_item_qty                  => i_item_qty,
                            p_item_rate                 => i_item_rate,
                            p_item_vat                  => i_item_vat,
                            p_urgent_fee                => i_urgent_fee,
                            p_service_charge            => i_service_charge,
                            p_itemtype_no               => i_itemtype_no,
                            p_par_itemtype_no           => i_par_itemtype_no,
                            p_bu_no                     => i_bu_no,
                            p_delivery_status_no        => i_delivery_status_no,
                            p_package_item_flag         => i_package_item_flag,
                            p_pur_rate                  => i_pur_rate,
                            p_inv_index                 => v_bill_index,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                            );
                      
    v_bill_index := 1;
    
    if nvl(p_disc_amount,0) > 0 then
        
        k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
        k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);            
  
        insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                  reg_no, invoice_no, admission_no, disc_type_no, pay_amt,
                                  pay_type_no, disc_auth_by, disc_remarks, ss_creator, 
                                  ss_created_on, ss_created_session, company_no)
        values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
               v_reg_no, p_invoice_no, p_admission_no, p_disctype_no, p_disc_amount,
               6, p_disc_auth_by, p_disc_remarks, p_ss_creator, 
               sysdate, p_ss_created_session, p_company_no);    
        
        loop
        
            k_general.pd_genarate_no ('SEQ_PAYDTL_NO', p_company_no, v_paydtl_no,'YY',10);    
        
            insert into bill_paymentdtl (paydtl_no, pay_no, pay_date, pay_datetime, 
                                         reg_no, invoice_no, invoicedtl_no, admission_no, 
                                         item_no, bill_module_no, disc_type_no, cli_disc_amt, 
                                         ss_creator, ss_created_on, ss_created_session, company_no)
            values(v_paydtl_no, v_pay_no, trunc(sysdate), sysdate,
                   v_reg_no, p_invoice_no, i_invoicedtl_no (v_bill_index), p_admission_no,
                   p_item_no (v_bill_index), p_bill_module_no, p_disctype_no, p_cli_disc_amt (v_bill_index),
                   p_ss_creator, sysdate, p_ss_created_session, p_company_no);
        
        exit when v_bill_index >= nvl (p_item_index, 0);
            v_bill_index := v_bill_index + 1; 
        end loop;
        
        i_pay_no        (1) := v_pay_no;
        i_pay_mode      (1) := null;
        i_coll_mode     (1) := null;
        i_pay_type_no   (1) := 6;
        i_amount        (1) := p_disc_amount;
        i_given_amt     (1) := null;
        
        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => 1,
                            p_disctype_no               => p_disctype_no,  
                            p_disc_auth_by              => p_disc_auth_by,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
        
    end if;
      
    if nvl(p_pay_index,0) > 0 then
    
        loop
        
            k_general.pd_genarate_id ('', 'BILL_PAYMENT', 'PAY_ID', p_company_no, v_pay_id);
            k_general.pd_genarate_no ('SEQ_PAY_NO', p_company_no, v_pay_no,'YY',10);
            
            insert into bill_payment (pay_no, pay_id, pay_date, pay_datetime, bill_module_no,
                                      reg_no, invoice_no, admission_no, pay_amt, 
                                      pay_type_no, pay_mode, coll_mode, pay_cqcc_others, 
                                      pay_bank_name, given_amt, ss_creator, 
                                      ss_created_on, ss_created_session, company_no)
            values(v_pay_no, v_pay_id, trunc(sysdate), sysdate, p_bill_module_no,
                   v_reg_no, p_invoice_no, p_admission_no, p_pay_amt (v_pay_index), 
                   p_pay_type_no (v_pay_index), p_pay_mode (v_pay_index), p_coll_mode (v_pay_index), p_pay_cqcc_others (v_pay_index), 
                   p_pay_bank_name (v_pay_index), p_given_amt (v_pay_index), p_ss_creator, 
                   sysdate, p_ss_created_session, p_company_no);
        
            i_pay_no        (v_pay_index) := v_pay_no;
            i_pay_mode      (v_pay_index) := p_pay_mode (v_pay_index);
            i_coll_mode     (v_pay_index) := p_coll_mode (v_pay_index);
            i_pay_type_no   (v_pay_index) := p_pay_type_no (v_pay_index);
            i_amount        (v_pay_index) := p_pay_amt (v_pay_index);
            i_given_amt     (v_pay_index) := p_given_amt (v_pay_index);
                
        exit when v_pay_index >= nvl (p_pay_index, 0);
            v_pay_index := v_pay_index + 1; 
        end loop;

        k_ledger.pd_ledger (p_reg_no                    => v_reg_no,
                            p_invoice_no                => p_invoice_no,
                            p_invoice_id                => p_invoice_id,
                            p_bill_module_no            => p_bill_module_no,
                            p_admission_no              => p_admission_no,
                            p_admission_id              => p_admission_id,
                            p_consultation_no           => p_consultation_no,
                            p_pay_no                    => i_pay_no,
                            p_pay_mode                  => i_pay_mode,
                            p_coll_mode                 => i_coll_mode,
                            p_pay_type_no               => i_pay_type_no,
                            p_amount                    => i_amount,
                            p_given_amt                 => i_given_amt,
                            p_index                     => v_pay_index,
                            p_disctype_no               => null,  
                            p_disc_auth_by              => null,
                            p_bed_no                    => p_bed_no,
                            p_ss_creator                => p_ss_creator,
                            p_og_no                     => p_og_no,
                            p_company_no                => p_company_no,
                            p_ss_created_session        => p_ss_created_session,
                            p_error                     => p_error
                    );
                    
    end if;
    
    if p_error is null then
        commit;     
    else
        rollback;
    end if;
    
exception when others then
    p_error := sqlerrm;
    rollback;
end pd_invoice_web;
                                                 
end k_opd;
/
