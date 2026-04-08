-- ============================================================
-- GACOM: Import 723 Wix users into Supabase auth + profiles
-- Run in Supabase SQL Editor. Users log in via Forgot Password.
-- ============================================================

ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;

DO $$
DECLARE v_uid UUID;
BEGIN

  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kehindealaka15.acl@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kehindealaka15.acl@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kehindealaka15acl','display_name','Kehindealaka Acl'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kehindealaka15acl','Kehindealaka Acl','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nuhunicholas23@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nuhunicholas23@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nuhunicholas23','display_name','Nuhunicholas'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nuhunicholas23','Nuhunicholas','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='immaculateumeh70@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','immaculateumeh70@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','immaculateumeh70','display_name','Immaculateumeh'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'immaculateumeh70','Immaculateumeh','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nifemiadesanya5006@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nifemiadesanya5006@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nifemiadesanya5006','display_name','Nifemiadesanya'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nifemiadesanya5006','Nifemiadesanya','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nurudeeny014@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nurudeeny014@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nurudeeny014','display_name','Nurudeeny'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nurudeeny014','Nurudeeny','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oshearuvie826@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oshearuvie826@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oshearuvie826','display_name','Oshearuvie'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oshearuvie826','Oshearuvie','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ibsdaone2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ibsdaone2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ibsdaone2','display_name','Ibsdaone'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ibsdaone2','Ibsdaone','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='para090645@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','para090645@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','para090645','display_name','Para'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'para090645','Para','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shogunleayomide15@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shogunleayomide15@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shogunleayomide15','display_name','Ayomide Shogunle'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shogunleayomide15','Ayomide Shogunle','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayeeyshababubabu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayeeyshababubabu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayeeyshababubabu','display_name','Ayeeyshababubabu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayeeyshababubabu','Ayeeyshababubabu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babangidafaizat2021@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babangidafaizat2021@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babangidafaizat2021','display_name','Babangidafaizat'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babangidafaizat2021','Babangidafaizat','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='udoetoks@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','udoetoks@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','udoetoks','display_name','Udoetoks'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'udoetoks','Udoetoks','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='basseychinecheremdaniel44@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','basseychinecheremdaniel44@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','basseychinecheremdaniel44','display_name','Basseychinecheremdaniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'basseychinecheremdaniel44','Basseychinecheremdaniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='theprinceof9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','theprinceof9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','theprinceof9','display_name','Odunayo Bukola-Balogun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'theprinceof9','Odunayo Bukola-Balogun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aliyuinuwa20@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aliyuinuwa20@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aliyuinuwa20','display_name','Aliyuinuwa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aliyuinuwa20','Aliyuinuwa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yahuzaalmajir2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yahuzaalmajir2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yahuzaalmajir2','display_name','Yahuzaalmajir'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yahuzaalmajir2','Yahuzaalmajir','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='125asdrea@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','125asdrea@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','125asdrea','display_name','James Chris'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'125asdrea','James Chris','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tamswellbb@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tamswellbb@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tamswellbb','display_name','Tamswellbb'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tamswellbb','Tamswellbb','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tunrayob4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tunrayob4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tunrayob4','display_name','Tunrayob'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tunrayob4','Tunrayob','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='melvinprince78@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','melvinprince78@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','melvinprince78','display_name','Melvinprince'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'melvinprince78','Melvinprince','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kellwise508@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kellwise508@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kellwise508','display_name','Kellwise'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kellwise508','Kellwise','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='priscillaodutolu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','priscillaodutolu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','priscillaodutolu','display_name','Priscillaodutolu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'priscillaodutolu','Priscillaodutolu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='isiaqsekinat4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','isiaqsekinat4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','isiaqsekinat4','display_name','Isiaqsekinat'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'isiaqsekinat4','Isiaqsekinat','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tobynuga@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tobynuga@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tobynuga','display_name','Tobynuga'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tobynuga','Tobynuga','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='solentworld000@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','solentworld000@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','solentworld000','display_name','Solentworld'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'solentworld000','Solentworld','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ifemideonashoga@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ifemideonashoga@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ifemideonashoga','display_name','Onashoga Ifemide'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ifemideonashoga','Onashoga Ifemide','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='allwellbrownt@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','allwellbrownt@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','allwellbrownt','display_name','Tamunoibi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'allwellbrownt','Tamunoibi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sakaabiola1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sakaabiola1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sakaabiola1','display_name','Sakaabiola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sakaabiola1','Sakaabiola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelthankgod085@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelthankgod085@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelthankgod085','display_name','Emmanuelthankgod'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelthankgod085','Emmanuelthankgod','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adeyemitoyin837@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adeyemitoyin837@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adeyemitoyin837','display_name','Adeyemitoyin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adeyemitoyin837','Adeyemitoyin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='thatboytimiy@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','thatboytimiy@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','thatboytimiy','display_name','Thatboytimiy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'thatboytimiy','Thatboytimiy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jemeozor4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jemeozor4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jemeozor4','display_name','Jillian'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jemeozor4','Jillian','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='favouradesanmi43@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','favouradesanmi43@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','favouradesanmi43','display_name','Favouradesanmi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'favouradesanmi43','Favouradesanmi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='heleneffiong082@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','heleneffiong082@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','heleneffiong082','display_name','Heleneffiong'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'heleneffiong082','Heleneffiong','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oladinno2005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oladinno2005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oladinno2005','display_name','Oladinno'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oladinno2005','Oladinno','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dejnorthiphone@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dejnorthiphone@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dejnorthiphone','display_name','Dejnorthiphone'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dejnorthiphone','Dejnorthiphone','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='smilewrld4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','smilewrld4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','smilewrld4','display_name','Smile Wrld'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'smilewrld4','Smile Wrld','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='moceret368@morrobel.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','moceret368@morrobel.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','moceret368','display_name','Moceret'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'moceret368','Moceret','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chigozirimonuoha0@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chigozirimonuoha0@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chigozirimonuoha0','display_name','Chigozirimonuoha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chigozirimonuoha0','Chigozirimonuoha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='habiutsifuma@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','habiutsifuma@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','habiutsifuma','display_name','Habiut Sifuma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'habiutsifuma','Habiut Sifuma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='obij56073@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','obij56073@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','obij56073','display_name','Obij'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'obij56073','Obij','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aliabdulla5191@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aliabdulla5191@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aliabdulla5191','display_name','Aliabdulla'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aliabdulla5191','Aliabdulla','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='udohmichael058@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','udohmichael058@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','udohmichael058','display_name','Udohmichael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'udohmichael058','Udohmichael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='evilginx303@outlook.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','evilginx303@outlook.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','evilginx303','display_name','Evilginx'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'evilginx303','Evilginx','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tripgregs@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tripgregs@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tripgregs','display_name','Tripgregs'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tripgregs','Tripgregs','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tunrab4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tunrab4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tunrab4','display_name','Tunrab'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tunrab4','Tunrab','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mattewpeter819@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mattewpeter819@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mattewpeter819','display_name','Mattewpeter'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mattewpeter819','Mattewpeter','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayodeleoluwatosin420@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayodeleoluwatosin420@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayodeleoluwatosin420','display_name','Ayodeleoluwatosin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayodeleoluwatosin420','Ayodeleoluwatosin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dejiniyi127@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dejiniyi127@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dejiniyi127','display_name','Dejiniyi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dejiniyi127','Dejiniyi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='somtoemekakalu111@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','somtoemekakalu111@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','somtoemekakalu111','display_name','Somtochukwu Kalu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'somtoemekakalu111','Somtochukwu Kalu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tallwellbrown@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tallwellbrown@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tallwellbrown','display_name','Tallwellbrown'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tallwellbrown','Tallwellbrown','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jude72916@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jude72916@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jude72916','display_name','Jude'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jude72916','Jude','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='stephenadekoya19@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','stephenadekoya19@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','stephenadekoya19','display_name','Stephenadekoya'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'stephenadekoya19','Stephenadekoya','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adesokanmamo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adesokanmamo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adesokanmamo','display_name','Adesokanmamo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adesokanmamo','Adesokanmamo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='banmeketheo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','banmeketheo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','banmeketheo','display_name','Banmeketheo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'banmeketheo','Banmeketheo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mobtechsincorporate@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mobtechsincorporate@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mobtechsincorporate','display_name','Mobtechsincorporate'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mobtechsincorporate','Mobtechsincorporate','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adeprecious62@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adeprecious62@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adeprecious62','display_name','Adeprecious'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adeprecious62','Adeprecious','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='micdchukwu85@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','micdchukwu85@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','micdchukwu85','display_name','Micdchukwu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'micdchukwu85','Micdchukwu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidemusella77@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidemusella77@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidemusella77','display_name','Davidemusella'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidemusella77','Davidemusella','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kahleethjnr@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kahleethjnr@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kahleethjnr','display_name','Kahleethjnr'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kahleethjnr','Kahleethjnr','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='baturejunior49@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','baturejunior49@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','baturejunior49','display_name','Baturejunior'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'baturejunior49','Baturejunior','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samueltella15@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samueltella15@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samueltella15','display_name','Samueltella'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samueltella15','Samueltella','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluseyigreatodusote@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluseyigreatodusote@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluseyigreatodusote','display_name','Seyi Olusegun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluseyigreatodusote','Seyi Olusegun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sanniolumayokun@yahoo.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sanniolumayokun@yahoo.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sanniolumayokun','display_name','Sanniolumayokun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sanniolumayokun','Sanniolumayokun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hdjdjsme@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hdjdjsme@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hdjdjsme','display_name','Hdjdjsme'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hdjdjsme','Hdjdjsme','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oyinilesanmi14@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oyinilesanmi14@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oyinilesanmi14','display_name','Oyin Ilesanmi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oyinilesanmi14','Oyin Ilesanmi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gamezoners719@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gamezoners719@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gamezoners719','display_name','Gamezoners'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gamezoners719','Gamezoners','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='folukeelizabethhoney@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','folukeelizabethhoney@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','folukeelizabethhoney','display_name','Folukeelizabethhoney'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'folukeelizabethhoney','Folukeelizabethhoney','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='djucreativity777@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','djucreativity777@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','djucreativity777','display_name','Djucreativity'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'djucreativity777','Djucreativity','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='amanalien2000@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','amanalien2000@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','amanalien2000','display_name','Akinjide Akinyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'amanalien2000','Akinjide Akinyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okekebransson@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okekebransson@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okekebransson','display_name','Okekebransson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okekebransson','Okekebransson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jakande2005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jakande2005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jakande2005','display_name','Jakande'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jakande2005','Jakande','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mlifemoshob9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mlifemoshob9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mlifemoshob9','display_name','Mlifemoshob'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mlifemoshob9','Mlifemoshob','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adeyemiqudri64@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adeyemiqudri64@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adeyemiqudri64','display_name','Adeyemiqudri'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adeyemiqudri64','Adeyemiqudri','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='favourobuma@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','favourobuma@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','favourobuma','display_name','Favourobuma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'favourobuma','Favourobuma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='enochtoye1308@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','enochtoye1308@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','enochtoye1308','display_name','Enoch Oguntoye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'enochtoye1308','Enoch Oguntoye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='odekunlefavour93@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','odekunlefavour93@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','odekunlefavour93','display_name','Odekunlefavour'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'odekunlefavour93','Odekunlefavour','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayodejiharold@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayodejiharold@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayodejiharold','display_name','Ayodejiharold'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayodejiharold','Ayodejiharold','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gacom.inc@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gacom.inc@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gacominc','display_name','Biscuit'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gacominc','Biscuit','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='autahtafidah@gmali.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','autahtafidah@gmali.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','autahtafidah','display_name','Autahtafidah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'autahtafidah','Autahtafidah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gudetzezggf@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gudetzezggf@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gudetzezggf','display_name','Gudetzezggf'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gudetzezggf','Gudetzezggf','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluwagbengagbadegesin@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluwagbengagbadegesin@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluwagbengagbadegesin','display_name','Oluwagbengagbadegesin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluwagbengagbadegesin','Oluwagbengagbadegesin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adedokunmujeeb97@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adedokunmujeeb97@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adedokunmujeeb97','display_name','Adedokunmujeeb'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adedokunmujeeb97','Adedokunmujeeb','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='demiladeadelekun2020@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','demiladeadelekun2020@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','demiladeadelekun2020','display_name','Demiladeadelekun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'demiladeadelekun2020','Demiladeadelekun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adebayoadefemi222@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adebayoadefemi222@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adebayoadefemi222','display_name','Adebayoadefemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adebayoadefemi222','Adebayoadefemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ilechukwumercy09@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ilechukwumercy09@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ilechukwumercy09','display_name','Ilechukwu Mercy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ilechukwumercy09','Ilechukwu Mercy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chisomemmanuel2023@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chisomemmanuel2023@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chisomemmanuel2023','display_name','Chisomemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chisomemmanuel2023','Chisomemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tewabechshitem@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tewabechshitem@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tewabechshitem','display_name','Tewabechshitem'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tewabechshitem','Tewabechshitem','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lxggaming2694@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lxggaming2694@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lxggaming2694','display_name','Lxggaming'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lxggaming2694','Lxggaming','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='amromanoheguono123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','amromanoheguono123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','amromanoheguono123','display_name','Amromanoheguono'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'amromanoheguono123','Amromanoheguono','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='forbells29@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','forbells29@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','forbells29','display_name','Ebuka Oguamanam'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'forbells29','Ebuka Oguamanam','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='johnraphael481@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','johnraphael481@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','johnraphael481','display_name','Johnraphael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'johnraphael481','Johnraphael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='igbaemmanuel655@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','igbaemmanuel655@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','igbaemmanuel655','display_name','Igbaemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'igbaemmanuel655','Igbaemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='autahtafidah@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','autahtafidah@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','autahtafidah1','display_name','Autahtafidah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'autahtafidah1','Autahtafidah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akomolafekehinde1999@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akomolafekehinde1999@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akomolafekehinde1999','display_name','Akomolafekehinde'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akomolafekehinde1999','Akomolafekehinde','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='izalanath3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','izalanath3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','izalanath3','display_name','Izalanath'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'izalanath3','Izalanath','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='toluwanimiajiboso03@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','toluwanimiajiboso03@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','toluwanimiajiboso03','display_name','Toluwanimiajiboso'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'toluwanimiajiboso03','Toluwanimiajiboso','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fathiaidowu16@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fathiaidowu16@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fathiaidowu16','display_name','Fathiaidowu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fathiaidowu16','Fathiaidowu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='elouazzania.elhajjam@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','elouazzania.elhajjam@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','elouazzaniaelhajjam','display_name','Elouazzania Elhajjam'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'elouazzaniaelhajjam','Elouazzania Elhajjam','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmablessing1010@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmablessing1010@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmablessing1010','display_name','Emmablessing'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmablessing1010','Emmablessing','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chukwuemekauche89@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chukwuemekauche89@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chukwuemekauche89','display_name','Chukwuemekauche'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chukwuemekauche89','Chukwuemekauche','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='counterxmark999@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','counterxmark999@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','counterxmark999','display_name','Counterxmark'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'counterxmark999','Counterxmark','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='israelorubo2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','israelorubo2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','israelorubo2','display_name','Israelorubo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'israelorubo2','Israelorubo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='anietieben42@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','anietieben42@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','anietieben42','display_name','Anietieben'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'anietieben42','Anietieben','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='azeezsulaimon778@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','azeezsulaimon778@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','azeezsulaimon778','display_name','Azeezsulaimon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'azeezsulaimon778','Azeezsulaimon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mjamiu1301@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mjamiu1301@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mjamiu1301','display_name','Mjamiu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mjamiu1301','Mjamiu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='s89803200@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','s89803200@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','s89803200','display_name','S'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'s89803200','S','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sirsamjerry@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sirsamjerry@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sirsamjerry','display_name','Sirsamjerry'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sirsamjerry','Sirsamjerry','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abiodunalameem4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abiodunalameem4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abiodunalameem4','display_name','Abiodunalameem'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abiodunalameem4','Abiodunalameem','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aadedayo667@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aadedayo667@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aadedayo667','display_name','Aadedayo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aadedayo667','Aadedayo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmynba594@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmynba594@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmynba594','display_name','Emmynba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmynba594','Emmynba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mustygee95@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mustygee95@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mustygee95','display_name','Mustygee'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mustygee95','Mustygee','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='andrewsaviour666@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','andrewsaviour666@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','andrewsaviour666','display_name','Andrewsaviour'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'andrewsaviour666','Andrewsaviour','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yomioyebola11@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yomioyebola11@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yomioyebola11','display_name','Yomioyebola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yomioyebola11','Yomioyebola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lateefabeeb41@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lateefabeeb41@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lateefabeeb41','display_name','Lateefabeeb'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lateefabeeb41','Lateefabeeb','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wisdomgerald511@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wisdomgerald511@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wisdomgerald511','display_name','Wisdomgerald'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wisdomgerald511','Wisdomgerald','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tobadare06@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tobadare06@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tobadare06','display_name','Tobadare'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tobadare06','Tobadare','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='eolugbamila@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','eolugbamila@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','eolugbamila','display_name','Eolugbamila'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'eolugbamila','Eolugbamila','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='judeonyekwere0123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','judeonyekwere0123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','judeonyekwere0123','display_name','Judeonyekwere'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'judeonyekwere0123','Judeonyekwere','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='justetta123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','justetta123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','justetta123','display_name','Justetta'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'justetta123','Justetta','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='afolabimustapha88@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','afolabimustapha88@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','afolabimustapha88','display_name','Afolabimustapha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'afolabimustapha88','Afolabimustapha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kingdihak@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kingdihak@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kingdihak','display_name','Kingdihak'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kingdihak','Kingdihak','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ekureonyeka@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ekureonyeka@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ekureonyeka','display_name','Ekureonyeka'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ekureonyeka','Ekureonyeka','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='henshawjohnstone@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','henshawjohnstone@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','henshawjohnstone','display_name','Johnstone Henshaw'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'henshawjohnstone','Johnstone Henshaw','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sabiulawal084@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sabiulawal084@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sabiulawal084','display_name','Sabiulawal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sabiulawal084','Sabiulawal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ezeonyemaechi123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ezeonyemaechi123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ezeonyemaechi123','display_name','Ezeonyemaechi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ezeonyemaechi123','Ezeonyemaechi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='obasteezii@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','obasteezii@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','obasteezii','display_name','Obasteezii'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'obasteezii','Obasteezii','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='seze1009@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','seze1009@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','seze1009','display_name','Seze'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'seze1009','Seze','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ronaldomolaja333@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ronaldomolaja333@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ronaldomolaja333','display_name','Ronaldomolaja'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ronaldomolaja333','Ronaldomolaja','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okochika2694@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okochika2694@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okochika2694','display_name','Okochika'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okochika2694','Okochika','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='asuzukelechi481@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','asuzukelechi481@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','asuzukelechi481','display_name','Asuzukelechi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'asuzukelechi481','Asuzukelechi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='patrickemma285@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','patrickemma285@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','patrickemma285','display_name','Patrickemma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'patrickemma285','Patrickemma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samueljohnson5214@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samueljohnson5214@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samueljohnson5214','display_name','Samueljohnson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samueljohnson5214','Samueljohnson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='08130343o@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','08130343o@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','08130343o','display_name','O'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'08130343o','O','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mm7816769@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mm7816769@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mm7816769','display_name','Mm'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mm7816769','Mm','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ifechukwunnalue20@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ifechukwunnalue20@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ifechukwunnalue20','display_name','Ifechukwunnalue'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ifechukwunnalue20','Ifechukwunnalue','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='udochukwuukaiwo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','udochukwuukaiwo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','udochukwuukaiwo','display_name','Udochukwuukaiwo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'udochukwuukaiwo','Udochukwuukaiwo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nifemibanjoko301@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nifemibanjoko301@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nifemibanjoko301','display_name','Nifemibanjoko'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nifemibanjoko301','Nifemibanjoko','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='irewolesunday49@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','irewolesunday49@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','irewolesunday49','display_name','Irewolesunday'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'irewolesunday49','Irewolesunday','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='starsmvrt@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','starsmvrt@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','starsmvrt','display_name','Starsmvrt'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'starsmvrt','Starsmvrt','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jacobsjaysy@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jacobsjaysy@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jacobsjaysy','display_name','Jacobsjaysy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jacobsjaysy','Jacobsjaysy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yourprobot10@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yourprobot10@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yourprobot10','display_name','Yourprobot'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yourprobot10','Yourprobot','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kekeemma70@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kekeemma70@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kekeemma70','display_name','Kekeemma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kekeemma70','Kekeemma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='alaoridwan69@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','alaoridwan69@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','alaoridwan69','display_name','Alaoridwan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'alaoridwan69','Alaoridwan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelenyi806@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelenyi806@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelenyi806','display_name','Samuelenyi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelenyi806','Samuelenyi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='saviourofonime@yahoo.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','saviourofonime@yahoo.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','saviourofonime','display_name','Saviourofonime'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'saviourofonime','Saviourofonime','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='henshawjames17@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','henshawjames17@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','henshawjames17','display_name','James'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'henshawjames17','James','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='d04277415@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','d04277415@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','d04277415','display_name','D'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'d04277415','D','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='alexyokocha22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','alexyokocha22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','alexyokocha22','display_name','Alexyokocha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'alexyokocha22','Alexyokocha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='opatunjidonald@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','opatunjidonald@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','opatunjidonald','display_name','Opatunjidonald'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'opatunjidonald','Opatunjidonald','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='zainababdul458@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','zainababdul458@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','zainababdul458','display_name','Zainababdul'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'zainababdul458','Zainababdul','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluwalanapraiseemmanuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluwalanapraiseemmanuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluwalanapraiseemmanuel','display_name','Oluwalanapraiseemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluwalanapraiseemmanuel','Oluwalanapraiseemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rachaeljeremy135@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rachaeljeremy135@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rachaeljeremy135','display_name','Rachaeljeremy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rachaeljeremy135','Rachaeljeremy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mousavichristine@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mousavichristine@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mousavichristine','display_name','Mousavichristine'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mousavichristine','Mousavichristine','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='waynecodm.9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','waynecodm.9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','waynecodm9','display_name','Waynecodm'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'waynecodm9','Waynecodm','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='phemostiga@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','phemostiga@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','phemostiga','display_name','Phemostiga'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'phemostiga','Phemostiga','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joshuaehi01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joshuaehi01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joshuaehi01','display_name','Joshuaehi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joshuaehi01','Joshuaehi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='austinechinasa37@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','austinechinasa37@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','austinechinasa37','display_name','Austinechinasa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'austinechinasa37','Austinechinasa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='atik@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','atik@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','atik','display_name','Atik'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'atik','Atik','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mejatjohn@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mejatjohn@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mejatjohn','display_name','Mejatjohn'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mejatjohn','Mejatjohn','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jovienloba1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jovienloba1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jovienloba1','display_name','Jovienloba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jovienloba1','Jovienloba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ajijagba@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ajijagba@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ajijagba','display_name','Ajijagba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ajijagba','Ajijagba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='damilaredavid777@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','damilaredavid777@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','damilaredavid777','display_name','Damilaredavid'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'damilaredavid777','Damilaredavid','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ismeabubakarusman@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ismeabubakarusman@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ismeabubakarusman','display_name','Ismeabubakarusman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ismeabubakarusman','Ismeabubakarusman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nnahchidindu0198@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nnahchidindu0198@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nnahchidindu0198','display_name','Nnahchidindu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nnahchidindu0198','Nnahchidindu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dghreatone17@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dghreatone17@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dghreatone17','display_name','Dghreatone'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dghreatone17','Dghreatone','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='omoniyiopemipo8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','omoniyiopemipo8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','omoniyiopemipo8','display_name','Omoniyiopemipo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'omoniyiopemipo8','Omoniyiopemipo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='benedictprecious820@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','benedictprecious820@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','benedictprecious820','display_name','Benedictprecious'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'benedictprecious820','Benedictprecious','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='enaikeleomoh@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','enaikeleomoh@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','enaikeleomoh','display_name','Enaikeleomoh'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'enaikeleomoh','Enaikeleomoh','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wurdbest500@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wurdbest500@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wurdbest500','display_name','Wurdbest'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wurdbest500','Wurdbest','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='isrealmary805@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','isrealmary805@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','isrealmary805','display_name','Isrealmary'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'isrealmary805','Isrealmary','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rajikazeem807@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rajikazeem807@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rajikazeem807','display_name','Rajikazeem'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rajikazeem807','Rajikazeem','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='alegekingsley@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','alegekingsley@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','alegekingsley','display_name','Alegekingsley'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'alegekingsley','Alegekingsley','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='damilolacomfort21@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','damilolacomfort21@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','damilolacomfort21','display_name','Damilolacomfort'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'damilolacomfort21','Damilolacomfort','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fabianmichael073@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fabianmichael073@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fabianmichael073','display_name','Fabianmichael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fabianmichael073','Fabianmichael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='onomeutoware@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','onomeutoware@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','onomeutoware','display_name','Onomeutoware'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'onomeutoware','Onomeutoware','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mikebrew988@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mikebrew988@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mikebrew988','display_name','Mikebrew'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mikebrew988','Mikebrew','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='austintreasure20@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','austintreasure20@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','austintreasure20','display_name','Austintreasure'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'austintreasure20','Austintreasure','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kaluchukwuma993@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kaluchukwuma993@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kaluchukwuma993','display_name','Kaluchukwuma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kaluchukwuma993','Kaluchukwuma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='onwubikochikanyem@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','onwubikochikanyem@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','onwubikochikanyem','display_name','Onwubikochikanyem'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'onwubikochikanyem','Onwubikochikanyem','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='iadeola046@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','iadeola046@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','iadeola046','display_name','Iadeola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'iadeola046','Iadeola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayeniabraham59@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayeniabraham59@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayeniabraham59','display_name','Ayeniabraham'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayeniabraham59','Ayeniabraham','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ajileyedorcas2244@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ajileyedorcas2244@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ajileyedorcas2244','display_name','Ajileyedorcas'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ajileyedorcas2244','Ajileyedorcas','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ikechukwuaugustine782@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ikechukwuaugustine782@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ikechukwuaugustine782','display_name','Ikechukwuaugustine'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ikechukwuaugustine782','Ikechukwuaugustine','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adedayodavis06@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adedayodavis06@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adedayodavis06','display_name','Adedayodavis'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adedayodavis06','Adedayodavis','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lanzema33@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lanzema33@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lanzema33','display_name','Lanzema'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lanzema33','Lanzema','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='russellsimon602@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','russellsimon602@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','russellsimon602','display_name','Russellsimon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'russellsimon602','Russellsimon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='agbasmoses@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','agbasmoses@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','agbasmoses','display_name','Agbasmoses'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'agbasmoses','Agbasmoses','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='assalafigumel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','assalafigumel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','assalafigumel','display_name','Assalafigumel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'assalafigumel','Assalafigumel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akashkevat441@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akashkevat441@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akashkevat441','display_name','Akashkevat'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akashkevat441','Akashkevat','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nnahvikky@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nnahvikky@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nnahvikky','display_name','Nnahvikky'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nnahvikky','Nnahvikky','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aniekemejerome209@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aniekemejerome209@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aniekemejerome209','display_name','Aniekemejerome'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aniekemejerome209','Aniekemejerome','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michaelbusari8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michaelbusari8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michaelbusari8','display_name','Michaelbusari'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michaelbusari8','Michaelbusari','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chinecheremumeh9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chinecheremumeh9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chinecheremumeh9','display_name','Chinecheremumeh'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chinecheremumeh9','Chinecheremumeh','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kekeemmanuel70@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kekeemmanuel70@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kekeemmanuel70','display_name','Kekeemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kekeemmanuel70','Kekeemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ikeleblossom3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ikeleblossom3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ikeleblossom3','display_name','Ikeleblossom'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ikeleblossom3','Ikeleblossom','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='goodluckobasi16@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','goodluckobasi16@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','goodluckobasi16','display_name','Goodluckobasi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'goodluckobasi16','Goodluckobasi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mw434542@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mw434542@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mw434542','display_name','Mw'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mw434542','Mw','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lectenmarine@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lectenmarine@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lectenmarine','display_name','Lectenmarine'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lectenmarine','Lectenmarine','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ajibadeemmanuel710@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ajibadeemmanuel710@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ajibadeemmanuel710','display_name','Ajibadeemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ajibadeemmanuel710','Ajibadeemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='marcusjohnbull52@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','marcusjohnbull52@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','marcusjohnbull52','display_name','Marcusjohnbull'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'marcusjohnbull52','Marcusjohnbull','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='maddyedward96@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','maddyedward96@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','maddyedward96','display_name','Maddyedward'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'maddyedward96','Maddyedward','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adimavijayjethro@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adimavijayjethro@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adimavijayjethro','display_name','Adimavijayjethro'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adimavijayjethro','Adimavijayjethro','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='beastjaw27@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','beastjaw27@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','beastjaw27','display_name','Beastjaw'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'beastjaw27','Beastjaw','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='trustvvera@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','trustvvera@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','trustvvera','display_name','Trustvvera'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'trustvvera','Trustvvera','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abuibrahim8069@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abuibrahim8069@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abuibrahim8069','display_name','Abuibrahim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abuibrahim8069','Abuibrahim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ebubetony6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ebubetony6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ebubetony6','display_name','Ebubetony'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ebubetony6','Ebubetony','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ahmaddansarai247@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ahmaddansarai247@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ahmaddansarai247','display_name','Ahmaddansarai'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ahmaddansarai247','Ahmaddansarai','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='balogune932@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','balogune932@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','balogune932','display_name','Balogune'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'balogune932','Balogune','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lovedayuloma59@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lovedayuloma59@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lovedayuloma59','display_name','Lovedayuloma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lovedayuloma59','Lovedayuloma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adzaageedavid03@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adzaageedavid03@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adzaageedavid03','display_name','Adzaageedavid'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adzaageedavid03','Adzaageedavid','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmamich56@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmamich56@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmamich56','display_name','Emmamich'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmamich56','Emmamich','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rufuselijah6704@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rufuselijah6704@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rufuselijah6704','display_name','Rufuselijah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rufuselijah6704','Rufuselijah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='danieladekoya252@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','danieladekoya252@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','danieladekoya252','display_name','Adekoya Daniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'danieladekoya252','Adekoya Daniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michealbenjamincj.234@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michealbenjamincj.234@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michealbenjamincj234','display_name','Michealbenjamincj'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michealbenjamincj234','Michealbenjamincj','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ukponomfon67@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ukponomfon67@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ukponomfon67','display_name','Ukponomfon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ukponomfon67','Ukponomfon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='inumidundamilola2020@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','inumidundamilola2020@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','inumidundamilola2020','display_name','Inumidundamilola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'inumidundamilola2020','Inumidundamilola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rabiusamaila2019@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rabiusamaila2019@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rabiusamaila2019','display_name','Rabiusamaila'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rabiusamaila2019','Rabiusamaila','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arizone4005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arizone4005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arizone4005','display_name','Arizone'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arizone4005','Arizone','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ceciliaiornumbe003@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ceciliaiornumbe003@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ceciliaiornumbe003','display_name','Ceciliaiornumbe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ceciliaiornumbe003','Ceciliaiornumbe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akanderokeeb4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akanderokeeb4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akanderokeeb4','display_name','Akanderokeeb'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akanderokeeb4','Akanderokeeb','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ogayiozioma588@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ogayiozioma588@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ogayiozioma588','display_name','Ogayiozioma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ogayiozioma588','Ogayiozioma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ekenea368@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ekenea368@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ekenea368','display_name','Ekenea'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ekenea368','Ekenea','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hallirulawallawal@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hallirulawallawal@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hallirulawallawal','display_name','Hallirulawallawal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hallirulawallawal','Hallirulawallawal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='putellas02@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','putellas02@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','putellas02','display_name','Putellas'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'putellas02','Putellas','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adekanmipeace9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adekanmipeace9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adekanmipeace9','display_name','Adekanmipeace'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adekanmipeace9','Adekanmipeace','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lawrenceoluwadarasimi334@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lawrenceoluwadarasimi334@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lawrenceoluwadarasimi334','display_name','Lawrenceoluwadarasimi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lawrenceoluwadarasimi334','Lawrenceoluwadarasimi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yahayaharuna6222@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yahayaharuna6222@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yahayaharuna6222','display_name','Yahayaharuna'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yahayaharuna6222','Yahayaharuna','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bamgboyeoladapo2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bamgboyeoladapo2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bamgboyeoladapo2','display_name','Bamgboyeoladapo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bamgboyeoladapo2','Bamgboyeoladapo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='praisechukwujama23@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','praisechukwujama23@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','praisechukwujama23','display_name','Praisechukwujama'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'praisechukwujama23','Praisechukwujama','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babalolatomiwa2005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babalolatomiwa2005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babalolatomiwa2005','display_name','Babalolatomiwa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babalolatomiwa2005','Babalolatomiwa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akeembiobaku24@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akeembiobaku24@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akeembiobaku24','display_name','Akeembiobaku'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akeembiobaku24','Akeembiobaku','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='marcellinusmoses6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','marcellinusmoses6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','marcellinusmoses6','display_name','Marcellinusmoses'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'marcellinusmoses6','Marcellinusmoses','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fortuneakinyemi29@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fortuneakinyemi29@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fortuneakinyemi29','display_name','Fortuneakinyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fortuneakinyemi29','Fortuneakinyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ubongabasiekerete4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ubongabasiekerete4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ubongabasiekerete4','display_name','Ubongabasiekerete'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ubongabasiekerete4','Ubongabasiekerete','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='zannahbahulama01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','zannahbahulama01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','zannahbahulama01','display_name','Zannahbahulama'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'zannahbahulama01','Zannahbahulama','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gyungokadonog@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gyungokadonog@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gyungokadonog','display_name','Gyungokadonog'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gyungokadonog','Gyungokadonog','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='itzliyoung@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','itzliyoung@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','itzliyoung','display_name','Itzliyoung'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'itzliyoung','Itzliyoung','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okeziewisdom782@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okeziewisdom782@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okeziewisdom782','display_name','Okeziewisdom'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okeziewisdom782','Okeziewisdom','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mjamiuozovehe@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mjamiuozovehe@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mjamiuozovehe','display_name','Jamiu Muhammed'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mjamiuozovehe','Jamiu Muhammed','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='seun.caret@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','seun.caret@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','seuncaret','display_name','Seun Caret'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'seuncaret','Seun Caret','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='solomonekwe6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','solomonekwe6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','solomonekwe6','display_name','Solomonekwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'solomonekwe6','Solomonekwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ralphhmk47@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ralphhmk47@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ralphhmk47','display_name','Ralphhmk'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ralphhmk47','Ralphhmk','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jeremiahodogwu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jeremiahodogwu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jeremiahodogwu','display_name','Jeremiahodogwu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jeremiahodogwu','Jeremiahodogwu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='uduakimoh43@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','uduakimoh43@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','uduakimoh43','display_name','Uduakimoh'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'uduakimoh43','Uduakimoh','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='maxwellpro87@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','maxwellpro87@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','maxwellpro87','display_name','Maxwellpro'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'maxwellpro87','Maxwellpro','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ajileyedorcas@rocketmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ajileyedorcas@rocketmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ajileyedorcas','display_name','Ajileyedorcas'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ajileyedorcas','Ajileyedorcas','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='zyong3479@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','zyong3479@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','zyong3479','display_name','Zyong'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'zyong3479','Zyong','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ofonimes416@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ofonimes416@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ofonimes416','display_name','Ofonimes'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ofonimes416','Ofonimes','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shadrachinioluwa@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shadrachinioluwa@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shadrachinioluwa','display_name','Shadrachinioluwa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shadrachinioluwa','Shadrachinioluwa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akinimole11@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akinimole11@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akinimole11','display_name','Akinimole'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akinimole11','Akinimole','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rhemajnr05@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rhemajnr05@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rhemajnr05','display_name','Rhemajnr'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rhemajnr05','Rhemajnr','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adedokunopeyemi715@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adedokunopeyemi715@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adedokunopeyemi715','display_name','Adedokunopeyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adedokunopeyemi715','Adedokunopeyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chideralincoln174@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chideralincoln174@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chideralincoln174','display_name','Chideralincoln'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chideralincoln174','Chideralincoln','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hamzataliyu1111@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hamzataliyu1111@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hamzataliyu1111','display_name','Hamzataliyu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hamzataliyu1111','Hamzataliyu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='johnomolola190@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','johnomolola190@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','johnomolola190','display_name','Johnomolola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'johnomolola190','Johnomolola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kelvin69946102@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kelvin69946102@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kelvin69946102','display_name','Kelvin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kelvin69946102','Kelvin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chisomobinna409@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chisomobinna409@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chisomobinna409','display_name','Chisomobinna'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chisomobinna409','Chisomobinna','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='deboraholuwatimileyin3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','deboraholuwatimileyin3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','deboraholuwatimileyin3','display_name','Deboraholuwatimileyin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'deboraholuwatimileyin3','Deboraholuwatimileyin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='smilezinfinite9409@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','smilezinfinite9409@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','smilezinfinite9409','display_name','Smilezinfinite'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'smilezinfinite9409','Smilezinfinite','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='smallsule050@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','smallsule050@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','smallsule050','display_name','Smallsule'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'smallsule050','Smallsule','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulrahimadamutd@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulrahimadamutd@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulrahimadamutd','display_name','Abdulrahimadamutd'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulrahimadamutd','Abdulrahimadamutd','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adedokunopeyemi815@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adedokunopeyemi815@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adedokunopeyemi815','display_name','Adedokunopeyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adedokunopeyemi815','Adedokunopeyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='promaxmac8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','promaxmac8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','promaxmac8','display_name','Promaxmac'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'promaxmac8','Promaxmac','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='marybaby4me@yahoo.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','marybaby4me@yahoo.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','marybaby4me','display_name','Marybaby Me'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'marybaby4me','Marybaby Me','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='alabichristy2006@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','alabichristy2006@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','alabichristy2006','display_name','Alabichristy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'alabichristy2006','Alabichristy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ismailtanko777@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ismailtanko777@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ismailtanko777','display_name','Ismailtanko'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ismailtanko777','Ismailtanko','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abisolaboluwatife03@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abisolaboluwatife03@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abisolaboluwatife03','display_name','Abisolaboluwatife'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abisolaboluwatife03','Abisolaboluwatife','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adegbitetolulope2008@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adegbitetolulope2008@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adegbitetolulope2008','display_name','Adegbitetolulope'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adegbitetolulope2008','Adegbitetolulope','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='topzydee4joke@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','topzydee4joke@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','topzydee4joke','display_name','Topzydee Joke'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'topzydee4joke','Topzydee Joke','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fortuneusoro025@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fortuneusoro025@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fortuneusoro025','display_name','Fortuneusoro'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fortuneusoro025','Fortuneusoro','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ogizisaviour419@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ogizisaviour419@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ogizisaviour419','display_name','Ogizisaviour'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ogizisaviour419','Ogizisaviour','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='elkamalb@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','elkamalb@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','elkamalb','display_name','Elkamalb'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'elkamalb','Elkamalb','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sabisola0@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sabisola0@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sabisola0','display_name','Sabisola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sabisola0','Sabisola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kaccy121@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kaccy121@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kaccy121','display_name','Kaccy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kaccy121','Kaccy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelokechukwu.c.2005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelokechukwu.c.2005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelokechukwuc2005','display_name','Emmanuelokechukwu C'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelokechukwuc2005','Emmanuelokechukwu C','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='funmie0107@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','funmie0107@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','funmie0107','display_name','Funmie'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'funmie0107','Funmie','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='zimuo0007@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','zimuo0007@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','zimuo0007','display_name','Zimuo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'zimuo0007','Zimuo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ikechukwu12richard@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ikechukwu12richard@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ikechukwu12richard','display_name','Ikechukwu Richard'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ikechukwu12richard','Ikechukwu Richard','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adeoyeisrael08@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adeoyeisrael08@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adeoyeisrael08','display_name','Adeoyeisrael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adeoyeisrael08','Adeoyeisrael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dblord81@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dblord81@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dblord81','display_name','Dblord'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dblord81','Dblord','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='macualeysamson9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','macualeysamson9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','macualeysamson9','display_name','Macualeysamson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'macualeysamson9','Macualeysamson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mustepleazur@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mustepleazur@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mustepleazur','display_name','Mustepleazur'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mustepleazur','Mustepleazur','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='franknhodowo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','franknhodowo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','franknhodowo','display_name','Francis Ugbada'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'franknhodowo','Francis Ugbada','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michaelhorace61@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michaelhorace61@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michaelhorace61','display_name','Michaelhorace'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michaelhorace61','Michaelhorace','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hamedino224@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hamedino224@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hamedino224','display_name','Hamedino'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hamedino224','Hamedino','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='peacemartins02@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','peacemartins02@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','peacemartins02','display_name','Peacemartins'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'peacemartins02','Peacemartins','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lazekej@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lazekej@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lazekej','display_name','Lazekej'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lazekej','Lazekej','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olayemiheritage890@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olayemiheritage890@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olayemiheritage890','display_name','Olayemiheritage'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olayemiheritage890','Olayemiheritage','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shehusulaiman616@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shehusulaiman616@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shehusulaiman616','display_name','Shehusulaiman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shehusulaiman616','Shehusulaiman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adebimpeshittu59@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adebimpeshittu59@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adebimpeshittu59','display_name','Adebimpeshittu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adebimpeshittu59','Adebimpeshittu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tivlumun619@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tivlumun619@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tivlumun619','display_name','Tivlumun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tivlumun619','Tivlumun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mfonakpan975@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mfonakpan975@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mfonakpan975','display_name','Mfonakpan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mfonakpan975','Mfonakpan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='osinachinwokocha205@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','osinachinwokocha205@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','osinachinwokocha205','display_name','Osinachinwokocha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'osinachinwokocha205','Osinachinwokocha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hauwayakubujoseph@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hauwayakubujoseph@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hauwayakubujoseph','display_name','Hauwayakubujoseph'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hauwayakubujoseph','Hauwayakubujoseph','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akpanukpono17@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akpanukpono17@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akpanukpono17','display_name','Akpanukpono'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akpanukpono17','Akpanukpono','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelakinyode9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelakinyode9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelakinyode9','display_name','Emmanuelakinyode'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelakinyode9','Emmanuelakinyode','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abbankhadijajahun@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abbankhadijajahun@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abbankhadijajahun','display_name','Abbankhadijajahun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abbankhadijajahun','Abbankhadijajahun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='madallairmiya5@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','madallairmiya5@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','madallairmiya5','display_name','Madallairmiya'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'madallairmiya5','Madallairmiya','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='moh.danlamee@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','moh.danlamee@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mohdanlamee','display_name','Moh Danlamee'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mohdanlamee','Moh Danlamee','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='muhammadbjibril06@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','muhammadbjibril06@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','muhammadbjibril06','display_name','Muhammadbjibril'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'muhammadbjibril06','Muhammadbjibril','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='brightakinmulewo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','brightakinmulewo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','brightakinmulewo','display_name','Brightakinmulewo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'brightakinmulewo','Brightakinmulewo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okekep835@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okekep835@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okekep835','display_name','Paul Okeke'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okekep835','Paul Okeke','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mostunderratedtiger@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mostunderratedtiger@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mostunderratedtiger','display_name','Saheed Shobanjo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mostunderratedtiger','Saheed Shobanjo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='opeogunadegbola3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','opeogunadegbola3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','opeogunadegbola3','display_name','Opeogunadegbola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'opeogunadegbola3','Opeogunadegbola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samadhorpheyhemhi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samadhorpheyhemhi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samadhorpheyhemhi','display_name','Samadhorpheyhemhi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samadhorpheyhemhi','Samadhorpheyhemhi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayoadedaniel02@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayoadedaniel02@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayoadedaniel02','display_name','Ayoadedaniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayoadedaniel02','Ayoadedaniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kkukoyirapheal@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kkukoyirapheal@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kkukoyirapheal','display_name','Kkukoyirapheal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kkukoyirapheal','Kkukoyirapheal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shittusulaiman00@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shittusulaiman00@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shittusulaiman00','display_name','Shittusulaiman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shittusulaiman00','Shittusulaiman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='alufuokennneth@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','alufuokennneth@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','alufuokennneth','display_name','Alufuokennneth'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'alufuokennneth','Alufuokennneth','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='funshothaoban@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','funshothaoban@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','funshothaoban','display_name','Funshothaoban'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'funshothaoban','Funshothaoban','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jedthebeloved@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jedthebeloved@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jedthebeloved','display_name','Joseph Nwobodo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jedthebeloved','Joseph Nwobodo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tjengine2022@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tjengine2022@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tjengine2022','display_name','Tjengine'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tjengine2022','Tjengine','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='collinsokpara06@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','collinsokpara06@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','collinsokpara06','display_name','Collinsokpara'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'collinsokpara06','Collinsokpara','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nnamso65@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nnamso65@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nnamso65','display_name','Nnamso'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nnamso65','Nnamso','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dokuboprecious33@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dokuboprecious33@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dokuboprecious33','display_name','Good luck Dokubo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dokuboprecious33','Good luck Dokubo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samueloladunjoye4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samueloladunjoye4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samueloladunjoye4','display_name','Samueloladunjoye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samueloladunjoye4','Samueloladunjoye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adebanwoomogbolahan70@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adebanwoomogbolahan70@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adebanwoomogbolahan70','display_name','Gbolahan Adebanwo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adebanwoomogbolahan70','Gbolahan Adebanwo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akintomiwaogundeyi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akintomiwaogundeyi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akintomiwaogundeyi','display_name','Akintomiwaogundeyi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akintomiwaogundeyi','Akintomiwaogundeyi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='darasimiadebanjo28@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','darasimiadebanjo28@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','darasimiadebanjo28','display_name','Darasimiadebanjo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'darasimiadebanjo28','Darasimiadebanjo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='khamilaherominah@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','khamilaherominah@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','khamilaherominah','display_name','Khamilaherominah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'khamilaherominah','Khamilaherominah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='thegaminghubgacom@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','thegaminghubgacom@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','thegaminghubgacom','display_name','thegaminghub'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'thegaminghubgacom','thegaminghub','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kelechivivian662@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kelechivivian662@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kelechivivian662','display_name','Kelechivivian'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kelechivivian662','Kelechivivian','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='baloguntaiwo0001@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','baloguntaiwo0001@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','baloguntaiwo0001','display_name','Baloguntaiwo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'baloguntaiwo0001','Baloguntaiwo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ohejuwachristian@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ohejuwachristian@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ohejuwachristian','display_name','Ohejuwachristian'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ohejuwachristian','Ohejuwachristian','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='calebaderoju@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','calebaderoju@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','calebaderoju','display_name','Calebaderoju'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'calebaderoju','Calebaderoju','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ibrahimsaidu034@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ibrahimsaidu034@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ibrahimsaidu034','display_name','Ibrahimsaidu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ibrahimsaidu034','Ibrahimsaidu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmaboss4000@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmaboss4000@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmaboss4000','display_name','Emmaboss'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmaboss4000','Emmaboss','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='eshorgold@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','eshorgold@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','eshorgold','display_name','Eshorgold'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'eshorgold','Eshorgold','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babyuk019@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babyuk019@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babyuk019','display_name','Babyuk'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babyuk019','Babyuk','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olanrewajugbolahan321@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olanrewajugbolahan321@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olanrewajugbolahan321','display_name','Olanrewajugbolahan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olanrewajugbolahan321','Olanrewajugbolahan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='deborahobodoechi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','deborahobodoechi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','deborahobodoechi','display_name','Deborahobodoechi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'deborahobodoechi','Deborahobodoechi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='umehvictor00@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','umehvictor00@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','umehvictor00','display_name','Umehvictor'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'umehvictor00','Umehvictor','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='erictimi222@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','erictimi222@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','erictimi222','display_name','Eric Timilehin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'erictimi222','Eric Timilehin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='seanyodafe@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','seanyodafe@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','seanyodafe','display_name','Seanyodafe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'seanyodafe','Seanyodafe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oladewinola@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oladewinola@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oladewinola','display_name','Oladewinola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oladewinola','Oladewinola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oladejih6470@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oladejih6470@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oladejih6470','display_name','Oladejih'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oladejih6470','Oladejih','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ckennetizu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ckennetizu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ckennetizu','display_name','Ckennetizu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ckennetizu','Ckennetizu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='pelumi97@protonmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','pelumi97@protonmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','pelumi97','display_name','Pelumi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'pelumi97','Pelumi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='biensandra438@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','biensandra438@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','biensandra438','display_name','Biensandra'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'biensandra438','Biensandra','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelchristian2775@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelchristian2775@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelchristian2775','display_name','Emmanuelchristian'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelchristian2775','Emmanuelchristian','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fawazadebayo05@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fawazadebayo05@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fawazadebayo05','display_name','Fawazadebayo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fawazadebayo05','Fawazadebayo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='isaacarsan@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','isaacarsan@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','isaacarsan','display_name','Isaacarsan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'isaacarsan','Isaacarsan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='osayimwen.uwamose@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','osayimwen.uwamose@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','osayimwenuwamose','display_name','Osayimwen Uwamose'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'osayimwenuwamose','Osayimwen Uwamose','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='iboroaugustus@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','iboroaugustus@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','iboroaugustus','display_name','Iboroaugustus'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'iboroaugustus','Iboroaugustus','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nanakwame4245@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nanakwame4245@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nanakwame4245','display_name','Nanakwame'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nanakwame4245','Nanakwame','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='victorgodwin0008@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','victorgodwin0008@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','victorgodwin0008','display_name','Victorgodwin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'victorgodwin0008','Victorgodwin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='twinkletrend66@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','twinkletrend66@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','twinkletrend66','display_name','Twinkletrend'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'twinkletrend66','Twinkletrend','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olarongbedelight141@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olarongbedelight141@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olarongbedelight141','display_name','Olarongbedelight'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olarongbedelight141','Olarongbedelight','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olowoyeyecomfort2001@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olowoyeyecomfort2001@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olowoyeyecomfort2001','display_name','Olowoyeyecomfort'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olowoyeyecomfort2001','Olowoyeyecomfort','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayomayowa898@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayomayowa898@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayomayowa898','display_name','Ayomayowa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayomayowa898','Ayomayowa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='telly00133@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','telly00133@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','telly00133','display_name','Telly'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'telly00133','Telly','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='iavenbua@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','iavenbua@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','iavenbua','display_name','Iavenbua'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'iavenbua','Iavenbua','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wonderfulalabi028@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wonderfulalabi028@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wonderfulalabi028','display_name','Wonderfulalabi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wonderfulalabi028','Wonderfulalabi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joyarayi22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joyarayi22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joyarayi22','display_name','Joyarayi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joyarayi22','Joyarayi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='noelnoemzy@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','noelnoemzy@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','noelnoemzy','display_name','Noel Goodluck'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'noelnoemzy','Noel Goodluck','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='francisayokunlesunday@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','francisayokunlesunday@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','francisayokunlesunday','display_name','Francisayokunlesunday'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'francisayokunlesunday','Francisayokunlesunday','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ahmedopeyemi2000@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ahmedopeyemi2000@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ahmedopeyemi2000','display_name','Ahmedopeyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ahmedopeyemi2000','Ahmedopeyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='segunwilliams09@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','segunwilliams09@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','segunwilliams09','display_name','Segunwilliams'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'segunwilliams09','Segunwilliams','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arababobola9@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arababobola9@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arababobola9','display_name','Araba Adebobola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arababobola9','Araba Adebobola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aninopayeboye@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aninopayeboye@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aninopayeboye','display_name','Aninopayeboye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aninopayeboye','Aninopayeboye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='caasi9092@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','caasi9092@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','caasi9092','display_name','Isaac Ogunrinola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'caasi9092','Isaac Ogunrinola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nifemidan567@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nifemidan567@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nifemidan567','display_name','NIFEMI DANIEL'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nifemidan567','NIFEMI DANIEL','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oguntoyinbofatai422@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oguntoyinbofatai422@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oguntoyinbofatai422','display_name','Oguntoyinbofatai'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oguntoyinbofatai422','Oguntoyinbofatai','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okaform454@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okaform454@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okaform454','display_name','Okaform'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okaform454','Okaform','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abellamaria8610@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abellamaria8610@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abellamaria8610','display_name','Abellamaria'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abellamaria8610','Abellamaria','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arababobola@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arababobola@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arababobola','display_name','Arababobola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arababobola','Arababobola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='roseclarkson67@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','roseclarkson67@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','roseclarkson67','display_name','Roseclarkson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'roseclarkson67','Roseclarkson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chukwumarema529@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chukwumarema529@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chukwumarema529','display_name','Chukwumarema'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chukwumarema529','Chukwumarema','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='idemudiah621@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','idemudiah621@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','idemudiah621','display_name','Idemudia'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'idemudiah621','Idemudia','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dylanrooney619@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dylanrooney619@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dylanrooney619','display_name','Dylanrooney'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dylanrooney619','Dylanrooney','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='madumelubouch@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','madumelubouch@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','madumelubouch','display_name','Madumelubouch'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'madumelubouch','Madumelubouch','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abuolotuemmanuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abuolotuemmanuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abuolotuemmanuel','display_name','Abuolotuemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abuolotuemmanuel','Abuolotuemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='martadeen01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','martadeen01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','martadeen01','display_name','Martadeen'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'martadeen01','Martadeen','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='2buzoremma@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','2buzoremma@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','2buzoremma','display_name','Buzoremma'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'2buzoremma','Buzoremma','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='godfryben7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','godfryben7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','godfryben7','display_name','Godfryben'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'godfryben7','Godfryben','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nisaiah658@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nisaiah658@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nisaiah658','display_name','Nisaiah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nisaiah658','Nisaiah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='noelgoodluck5@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','noelgoodluck5@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','noelgoodluck5','display_name','Noel Goodluck'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'noelgoodluck5','Noel Goodluck','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='benjaminorike7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','benjaminorike7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','benjaminorike7','display_name','Benjaminorike'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'benjaminorike7','Benjaminorike','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='opemiposowemimo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','opemiposowemimo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','opemiposowemimo','display_name','Opemiposowemimo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'opemiposowemimo','Opemiposowemimo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mbeludaniel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mbeludaniel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mbeludaniel','display_name','Mbeludaniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mbeludaniel','Mbeludaniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='darlingtonariogho@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','darlingtonariogho@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','darlingtonariogho','display_name','Darlingtonariogho'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'darlingtonariogho','Darlingtonariogho','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayubsonchristopher@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayubsonchristopher@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayubsonchristopher','display_name','Ayubsonchristopher'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayubsonchristopher','Ayubsonchristopher','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelhabib5050@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelhabib5050@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelhabib5050','display_name','Samuelhabib'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelhabib5050','Samuelhabib','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akinrotimitemitope92@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akinrotimitemitope92@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akinrotimitemitope92','display_name','Akinrotimitemitope'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akinrotimitemitope92','Akinrotimitemitope','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='psalmod3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','psalmod3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','psalmod3','display_name','Psalmod'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'psalmod3','Psalmod','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='elissamelissa87@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','elissamelissa87@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','elissamelissa87','display_name','Elissamelissa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'elissamelissa87','Elissamelissa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ahmadkrisht2010@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ahmadkrisht2010@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ahmadkrisht2010','display_name','Ahmad Krisht'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ahmadkrisht2010','Ahmad Krisht','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='maliktosho27@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','maliktosho27@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','maliktosho27','display_name','Maliktosho'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'maliktosho27','Maliktosho','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mitchellolisehmedua@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mitchellolisehmedua@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mitchellolisehmedua','display_name','Mitchellolisehmedua'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mitchellolisehmedua','Mitchellolisehmedua','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='opemipofasanya08@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','opemipofasanya08@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','opemipofasanya08','display_name','Opemipo Fasanya'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'opemipofasanya08','Opemipo Fasanya','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joeleneojo2019@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joeleneojo2019@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joeleneojo2019','display_name','Joeleneojo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joeleneojo2019','Joeleneojo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='timkatsilas@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','timkatsilas@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','timkatsilas','display_name','Timkatsilas'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'timkatsilas','Timkatsilas','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='greatlifeinchrist4eva@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','greatlifeinchrist4eva@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','greatlifeinchrist4eva','display_name','Adeoluwa Adetilewa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'greatlifeinchrist4eva','Adeoluwa Adetilewa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='odigiedivinefavour@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','odigiedivinefavour@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','odigiedivinefavour','display_name','Odigiedivinefavour'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'odigiedivinefavour','Odigiedivinefavour','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='omonayajocitn@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','omonayajocitn@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','omonayajocitn','display_name','Omonayajocitn'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'omonayajocitn','Omonayajocitn','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ugonnayaugonna835@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ugonnayaugonna835@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ugonnayaugonna835','display_name','Ugonnayaugonna'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ugonnayaugonna835','Ugonnayaugonna','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dn5058356@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dn5058356@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dn5058356','display_name','Dn'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dn5058356','Dn','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='pducer10@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','pducer10@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','pducer10','display_name','Pducer'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'pducer10','Pducer','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='henryfreeman2006@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','henryfreeman2006@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','henryfreeman2006','display_name','Henryfreeman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'henryfreeman2006','Henryfreeman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='moneymaann07@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','moneymaann07@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','moneymaann07','display_name','Roman Silver'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'moneymaann07','Roman Silver','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adeboyekally27@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adeboyekally27@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adeboyekally27','display_name','Khally Khally'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adeboyekally27','Khally Khally','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='goodnewsibrahim299@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','goodnewsibrahim299@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','goodnewsibrahim299','display_name','Ibrahim Goodnews'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'goodnewsibrahim299','Ibrahim Goodnews','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adamgegele79@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adamgegele79@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adamgegele79','display_name','Adam Gegele'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adamgegele79','Adam Gegele','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kelanijohn040@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kelanijohn040@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kelanijohn040','display_name','John Kelani'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kelanijohn040','John Kelani','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='danieliheanacho2021@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','danieliheanacho2021@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','danieliheanacho2021','display_name','Daisuke Hax'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'danieliheanacho2021','Daisuke Hax','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tochexgaming@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tochexgaming@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tochexgaming','display_name','Tochex Games'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tochexgaming','Tochex Games','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='idibiajoseph06@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','idibiajoseph06@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','idibiajoseph06','display_name','Joseph Idibia'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'idibiajoseph06','Joseph Idibia','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fagbenromubarak7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fagbenromubarak7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fagbenromubarak7','display_name','Fagbenro Mubarak'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fagbenromubarak7','Fagbenro Mubarak','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michaelchidebere87@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michaelchidebere87@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michaelchidebere87','display_name','Danny Cross'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michaelchidebere87','Danny Cross','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ahmedfizane1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ahmedfizane1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ahmedfizane1','display_name','Ahmedfizane'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ahmedfizane1','Ahmedfizane','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abrahamayomide97@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abrahamayomide97@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abrahamayomide97','display_name','Abrahamayomide'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abrahamayomide97','Abrahamayomide','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chris16nv@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chris16nv@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chris16nv','display_name','Chris Etim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chris16nv','Chris Etim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='maltechtics@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','maltechtics@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','maltechtics','display_name','Abdulmalik Imuekemhe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'maltechtics','Abdulmalik Imuekemhe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wisdomchukwudi07042@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wisdomchukwudi07042@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wisdomchukwudi07042','display_name','Emmanuel Aina'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wisdomchukwudi07042','Emmanuel Aina','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arafatabdulmomin7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arafatabdulmomin7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arafatabdulmomin7','display_name','Arafatabdulmomin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arafatabdulmomin7','Arafatabdulmomin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fornfk64@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fornfk64@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fornfk64','display_name','Nfk Prime'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fornfk64','Nfk Prime','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shalomgeorge0602@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shalomgeorge0602@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shalomgeorge0602','display_name','Shalom George'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shalomgeorge0602','Shalom George','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='vicnitedigitals@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','vicnitedigitals@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','vicnitedigitals','display_name','Olotu Victor'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'vicnitedigitals','Olotu Victor','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okpogoroh@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okpogoroh@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okpogoroh','display_name','Okpogoro Henry Oghenekvwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okpogoroh','Okpogoro Henry Oghenekvwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='praise.eze1990@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','praise.eze1990@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','praiseeze1990','display_name','Praise Eze'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'praiseeze1990','Praise Eze','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='majestydanielgana@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','majestydanielgana@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','majestydanielgana','display_name','Gana Majesty daniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'majestydanielgana','Gana Majesty daniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ukpongdavid767@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ukpongdavid767@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ukpongdavid767','display_name','Casper DaGremlin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ukpongdavid767','Casper DaGremlin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jmj54798@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jmj54798@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jmj54798','display_name','Nafeez Idris'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jmj54798','Nafeez Idris','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='memoreality9876@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','memoreality9876@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','memoreality9876','display_name','Memo Reality'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'memoreality9876','Memo Reality','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ajala2277@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ajala2277@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ajala2277','display_name','Samuel Ajala'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ajala2277','Samuel Ajala','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulazeez0906y@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulazeez0906y@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulazeez0906y','display_name','Abdulazeez Abdulazeez'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulazeez0906y','Abdulazeez Abdulazeez','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidtimidamilare22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidtimidamilare22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidtimidamilare22','display_name','David Oluwatimilehin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidtimidamilare22','David Oluwatimilehin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='agboolaokikiola360@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','agboolaokikiola360@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','agboolaokikiola360','display_name','Agboola Okiki'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'agboolaokikiola360','Agboola Okiki','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hameedadebisi986@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hameedadebisi986@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hameedadebisi986','display_name','Adebisi Hameed'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hameedadebisi986','Adebisi Hameed','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidoojaide@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidoojaide@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidoojaide','display_name','Davidoojaide'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidoojaide','Davidoojaide','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='vitaliswise105@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','vitaliswise105@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','vitaliswise105','display_name','Vitaliswise'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'vitaliswise105','Vitaliswise','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okemeking@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okemeking@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okemeking','display_name','Okemeking'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okemeking','Okemeking','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mediamarkart@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mediamarkart@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mediamarkart','display_name','Mediamarkart'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mediamarkart','Mediamarkart','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akanbimichael00@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akanbimichael00@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akanbimichael00','display_name','Akanbi Micheal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akanbimichael00','Akanbi Micheal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdullahluwajuwon@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdullahluwajuwon@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdullahluwajuwon','display_name','Abdullahluwajuwon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdullahluwajuwon','Abdullahluwajuwon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='charlesegwunwoke@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','charlesegwunwoke@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','charlesegwunwoke','display_name','Charles Egwunwoke'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'charlesegwunwoke','Charles Egwunwoke','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lucianyourfada@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lucianyourfada@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lucianyourfada','display_name','Lucian Great'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lucianyourfada','Lucian Great','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='opeade0203@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','opeade0203@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','opeade0203','display_name','Adeyemi Opeyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'opeade0203','Adeyemi Opeyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='pukumakindnessmusa@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','pukumakindnessmusa@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','pukumakindnessmusa','display_name','Toxic King'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'pukumakindnessmusa','Toxic King','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fortetafabianbrakemi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fortetafabianbrakemi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fortetafabianbrakemi','display_name','Forteta Fabian'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fortetafabianbrakemi','Forteta Fabian','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rahimsoriq@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rahimsoriq@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rahimsoriq','display_name','Just a Chillguy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rahimsoriq','Just a Chillguy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='smiharriet8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','smiharriet8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','smiharriet8','display_name','Metro Boomer'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'smiharriet8','Metro Boomer','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='shobanjosaidat123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','shobanjosaidat123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','shobanjosaidat123','display_name','Shobanjosaidat'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'shobanjosaidat123','Shobanjosaidat','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oreokeme@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oreokeme@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oreokeme','display_name','King Gerald'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oreokeme','King Gerald','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abuchichigbu90@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abuchichigbu90@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abuchichigbu90','display_name','el Bombocl4t'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abuchichigbu90','el Bombocl4t','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='adejoc2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','adejoc2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','adejoc2','display_name','Christian Adejo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'adejoc2','Christian Adejo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='peteremma049@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','peteremma049@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','peteremma049','display_name','Bishop Minex'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'peteremma049','Bishop Minex','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='frankbello1512@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','frankbello1512@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','frankbello1512','display_name','Frankbello'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'frankbello1512','Frankbello','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='youngjohn80090@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','youngjohn80090@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','youngjohn80090','display_name','Adekunle Israel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'youngjohn80090','Adekunle Israel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='brightduru707@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','brightduru707@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','brightduru707','display_name','Brightduru'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'brightduru707','Brightduru','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chideraagah4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chideraagah4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chideraagah4','display_name','Agah Isaac'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chideraagah4','Agah Isaac','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='christopherchristian117@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','christopherchristian117@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','christopherchristian117','display_name','Christian Christopher'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'christopherchristian117','Christian Christopher','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ojoenoch2022@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ojoenoch2022@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ojoenoch2022','display_name','Tunademise Ojo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ojoenoch2022','Tunademise Ojo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='spencs5301@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','spencs5301@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','spencs5301','display_name','Spencs'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'spencs5301','Spencs','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kollinzwest00@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kollinzwest00@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kollinzwest00','display_name','Kollinzwest'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kollinzwest00','Kollinzwest','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chukssamuel131@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chukssamuel131@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chukssamuel131','display_name','Chukwuemeka Samuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chukssamuel131','Chukwuemeka Samuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmykelleharjnr@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmykelleharjnr@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmykelleharjnr','display_name','Kelleher Raphael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmykelleharjnr','Kelleher Raphael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='aduniyisamuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','aduniyisamuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','aduniyisamuel','display_name','Aduniyisamuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'aduniyisamuel','Aduniyisamuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bunmiadejuyigbe692@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bunmiadejuyigbe692@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bunmiadejuyigbe692','display_name','Dayo Adegoke'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bunmiadejuyigbe692','Dayo Adegoke','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='igneeln288@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','igneeln288@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','igneeln288','display_name','Joshua Campbell'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'igneeln288','Joshua Campbell','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='daudaisaac747@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','daudaisaac747@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','daudaisaac747','display_name','Daudaisaac'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'daudaisaac747','Daudaisaac','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='blessedavreson01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','blessedavreson01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','blessedavreson01','display_name','Avreson Blessed'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'blessedavreson01','Avreson Blessed','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emekamoses181@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emekamoses181@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emekamoses181','display_name','Emekamoses'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emekamoses181','Emekamoses','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='habdulhameedsaidu45@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','habdulhameedsaidu45@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','habdulhameedsaidu45','display_name','Saidu Abdulhameed'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'habdulhameedsaidu45','Saidu Abdulhameed','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='henryavreson@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','henryavreson@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','henryavreson','display_name','Henryavreson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'henryavreson','Henryavreson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ezihonyedikachukwu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ezihonyedikachukwu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ezihonyedikachukwu','display_name','Ezih Onyedikachukwu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ezihonyedikachukwu','Ezih Onyedikachukwu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='berryzapi99@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','berryzapi99@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','berryzapi99','display_name','Berry Zapi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'berryzapi99','Berry Zapi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ogunjimivictorv23@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ogunjimivictorv23@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ogunjimivictorv23','display_name','Victor Ogunjimi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ogunjimivictorv23','Victor Ogunjimi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='vyrus2468@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','vyrus2468@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','vyrus2468','display_name','Victor Adekunle'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'vyrus2468','Victor Adekunle','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ojshedrach@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ojshedrach@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ojshedrach','display_name','Shedrach Onah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ojshedrach','Shedrach Onah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayoolajoseph333@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayoolajoseph333@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayoolajoseph333','display_name','Joseph Ayoola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayoolajoseph333','Joseph Ayoola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulwasiubasit4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulwasiubasit4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulwasiubasit4','display_name','Abdulwasiubasit'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulwasiubasit4','Abdulwasiubasit','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mortalffhxx@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mortalffhxx@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mortalffhxx','display_name','Mortal FF'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mortalffhxx','Mortal FF','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='taofeeqshittu63@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','taofeeqshittu63@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','taofeeqshittu63','display_name','Shittu Muhammadtaofeeq'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'taofeeqshittu63','Shittu Muhammadtaofeeq','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sadiqadavizefarouk24@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sadiqadavizefarouk24@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sadiqadavizefarouk24','display_name','Farouk Sadiq'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sadiqadavizefarouk24','Farouk Sadiq','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='asarikennedy3@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','asarikennedy3@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','asarikennedy3','display_name','Nb Kenny'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'asarikennedy3','Nb Kenny','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='benmaxorons@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','benmaxorons@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','benmaxorons','display_name','Benedict Oronsaye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'benmaxorons','Benedict Oronsaye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olukotunjoshua22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olukotunjoshua22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olukotunjoshua22','display_name','Joshua Olukotun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olukotunjoshua22','Joshua Olukotun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidokoccha@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidokoccha@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidokoccha','display_name','David Okocha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidokoccha','David Okocha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayobamialmustapha695@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayobamialmustapha695@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayobamialmustapha695','display_name','Ayobami Almustapha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayobamialmustapha695','Ayobami Almustapha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='erobijohnpaul@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','erobijohnpaul@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','erobijohnpaul','display_name','Johnpaul Erobi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'erobijohnpaul','Johnpaul Erobi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fortunekenegharevba@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fortunekenegharevba@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fortunekenegharevba','display_name','Fortunekenegharevba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fortunekenegharevba','Fortunekenegharevba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ehimenjeffrey58@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ehimenjeffrey58@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ehimenjeffrey58','display_name','Ehimen Jeffrey'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ehimenjeffrey58','Ehimen Jeffrey','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='faridahajagbe@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','faridahajagbe@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','faridahajagbe','display_name','Faidah Adenike'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'faridahajagbe','Faidah Adenike','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='grammz2023@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','grammz2023@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','grammz2023','display_name','David Michael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'grammz2023','David Michael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joek2173@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joek2173@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joek2173','display_name','Adebayo Joseph'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joek2173','Adebayo Joseph','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='imuzezesamuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','imuzezesamuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','imuzezesamuel','display_name','Imuzeze Samuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'imuzezesamuel','Imuzeze Samuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='docstandardcooperation@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','docstandardcooperation@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','docstandardcooperation','display_name','Daniel Uwakwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'docstandardcooperation','Daniel Uwakwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sammydiamond321@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sammydiamond321@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sammydiamond321','display_name','Samuel Olukorede'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sammydiamond321','Samuel Olukorede','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='josephojay79@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','josephojay79@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','josephojay79','display_name','Josephojay'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'josephojay79','Josephojay','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='iniceles05@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','iniceles05@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','iniceles05','display_name','Inimfon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'iniceles05','Inimfon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='phantomgrimreaper5@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','phantomgrimreaper5@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','phantomgrimreaper5','display_name','Kiyotaka Ayanokoji'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'phantomgrimreaper5','Kiyotaka Ayanokoji','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='angels4elisha@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','angels4elisha@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','angels4elisha','display_name','Elisha Esaigun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'angels4elisha','Elisha Esaigun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='otabordivine668@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','otabordivine668@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','otabordivine668','display_name','Otabor Divine'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'otabordivine668','Otabor Divine','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelomitiran7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelomitiran7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelomitiran7','display_name','Samuel Omitiran'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelomitiran7','Samuel Omitiran','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nwosusochi23@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nwosusochi23@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nwosusochi23','display_name','Nwosu Sochima'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nwosusochi23','Nwosu Sochima','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='princyudoh@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','princyudoh@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','princyudoh','display_name','Madara Uchiha'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'princyudoh','Madara Uchiha','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joshuaogung@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joshuaogung@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joshuaogung','display_name','Joshua Ogugbile'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joshuaogung','Joshua Ogugbile','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='godwillkaliamah@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','godwillkaliamah@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','godwillkaliamah','display_name','God''sWill Kalu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'godwillkaliamah','God''sWill Kalu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='georgewillbert915@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','georgewillbert915@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','georgewillbert915','display_name','Georgewillbert'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'georgewillbert915','Georgewillbert','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='onyeckachiemmanuel69@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','onyeckachiemmanuel69@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','onyeckachiemmanuel69','display_name','Onyeckachiemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'onyeckachiemmanuel69','Onyeckachiemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulbakibello009@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulbakibello009@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulbakibello009','display_name','Abdulbakibello'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulbakibello009','Abdulbakibello','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ifemhedey0@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ifemhedey0@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ifemhedey0','display_name','Ifemhedey'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ifemhedey0','Ifemhedey','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='soloboda110@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','soloboda110@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','soloboda110','display_name','Soloboda'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'soloboda110','Soloboda','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okoliemmanuel591@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okoliemmanuel591@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okoliemmanuel591','display_name','Emmanuel Okoli'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okoliemmanuel591','Emmanuel Okoli','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ayamwise123@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ayamwise123@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ayamwise123','display_name','Ayamwise'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ayamwise123','Ayamwise','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluwadamilolakoya@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluwadamilolakoya@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluwadamilolakoya','display_name','Oluwadamilolakoya'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluwadamilolakoya','Oluwadamilolakoya','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mazeedfiyinfoluwa@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mazeedfiyinfoluwa@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mazeedfiyinfoluwa','display_name','Mazeedfiyinfoluwa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mazeedfiyinfoluwa','Mazeedfiyinfoluwa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fornfk824@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fornfk824@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fornfk824','display_name','NFK Prime'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fornfk824','NFK Prime','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmatech2204@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmatech2204@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmatech2204','display_name','Emmanuel Kolade'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmatech2204','Emmanuel Kolade','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nnamdim76@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nnamdim76@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nnamdim76','display_name','Nnamdim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nnamdim76','Nnamdim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='deneh602@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','deneh602@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','deneh602','display_name','Deneh'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'deneh602','Deneh','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kingston11112008@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kingston11112008@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kingston11112008','display_name','Kingston'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kingston11112008','Kingston','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yusufboty252@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yusufboty252@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yusufboty252','display_name','Yusufboty'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yusufboty252','Yusufboty','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='egaminghub1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','egaminghub1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','egaminghub1','display_name','Egaminghub'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'egaminghub1','Egaminghub','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='princezy903@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','princezy903@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','princezy903','display_name','Princezy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'princezy903','Princezy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='creedzilla6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','creedzilla6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','creedzilla6','display_name','Creedzilla'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'creedzilla6','Creedzilla','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jamesstiles1q@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jamesstiles1q@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jamesstiles1q','display_name','Jamesstiles Q'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jamesstiles1q','Jamesstiles Q','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ramadhanyusuf346@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ramadhanyusuf346@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ramadhanyusuf346','display_name','Ramadhanyusuf'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ramadhanyusuf346','Ramadhanyusuf','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tenipaz120@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tenipaz120@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tenipaz120','display_name','Tenipaz'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tenipaz120','Tenipaz','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sodiqyinka137@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sodiqyinka137@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sodiqyinka137','display_name','Sodiqyinka'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sodiqyinka137','Sodiqyinka','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jackdemon966@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jackdemon966@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jackdemon966','display_name','Jackdemon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jackdemon966','Jackdemon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='otunbakehinde11@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','otunbakehinde11@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','otunbakehinde11','display_name','Otunbakehinde'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'otunbakehinde11','Otunbakehinde','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='techhonorable2009@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','techhonorable2009@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','techhonorable2009','display_name','Monday Great Ekele'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'techhonorable2009','Monday Great Ekele','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluwatobioyegade22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluwatobioyegade22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluwatobioyegade22','display_name','Oluwatobioyegade'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluwatobioyegade22','Oluwatobioyegade','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='isahali040@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','isahali040@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','isahali040','display_name','Isahali'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'isahali040','Isahali','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abbysax12@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abbysax12@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abbysax12','display_name','Abraham Salifu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abbysax12','Abraham Salifu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okechukwugreat4k@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okechukwugreat4k@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okechukwugreat4k','display_name','Okechukwugreat K'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okechukwugreat4k','Okechukwugreat K','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chukwundik01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chukwundik01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chukwundik01','display_name','Chukwundik'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chukwundik01','Chukwundik','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rosamccarter49@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rosamccarter49@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rosamccarter49','display_name','Rosamccarter'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rosamccarter49','Rosamccarter','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='matapaandrew01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','matapaandrew01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','matapaandrew01','display_name','Matapaandrew'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'matapaandrew01','Matapaandrew','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olamideawolaja948@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olamideawolaja948@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olamideawolaja948','display_name','Olamideawolaja'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olamideawolaja948','Olamideawolaja','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tikrennbs@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tikrennbs@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tikrennbs','display_name','RENN Renn'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tikrennbs','RENN Renn','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='eabu2285@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','eabu2285@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','eabu2285','display_name','Emmanuel John'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'eabu2285','Emmanuel John','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='vcphantom73@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','vcphantom73@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','vcphantom73','display_name','Vcphantom'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'vcphantom73','Vcphantom','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nandomcherish027@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nandomcherish027@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nandomcherish027','display_name','Nandomcherish'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nandomcherish027','Nandomcherish','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rufaifatia24434@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rufaifatia24434@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rufaifatia24434','display_name','Rufaifatia'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rufaifatia24434','Rufaifatia','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sammytope5@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sammytope5@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sammytope5','display_name','Sammytope'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sammytope5','Sammytope','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='faletiifedolapo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','faletiifedolapo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','faletiifedolapo','display_name','Demilade Faleti'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'faletiifedolapo','Demilade Faleti','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kingezra145@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kingezra145@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kingezra145','display_name','Kingezra'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kingezra145','Kingezra','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='matthewsort61@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','matthewsort61@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','matthewsort61','display_name','Matthewsort'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'matthewsort61','Matthewsort','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='greatedewor89@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','greatedewor89@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','greatedewor89','display_name','Greatedewor'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'greatedewor89','Greatedewor','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='meekman95@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','meekman95@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','meekman95','display_name','Meekman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'meekman95','Meekman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='isiomapraise6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','isiomapraise6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','isiomapraise6','display_name','Isiomapraise'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'isiomapraise6','Isiomapraise','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ibukunoluwafemi42@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ibukunoluwafemi42@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ibukunoluwafemi42','display_name','ibukun oluwafemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ibukunoluwafemi42','ibukun oluwafemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ibezimjoy2017@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ibezimjoy2017@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ibezimjoy2017','display_name','Ibezimjoy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ibezimjoy2017','Ibezimjoy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='amaechidaniel112@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','amaechidaniel112@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','amaechidaniel112','display_name','Amaechidaniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'amaechidaniel112','Amaechidaniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulsalamadio7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulsalamadio7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulsalamadio7','display_name','Abdulsalamadio'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulsalamadio7','Abdulsalamadio','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dakjzkgba@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dakjzkgba@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dakjzkgba','display_name','Dakjzkgba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dakjzkgba','Dakjzkgba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='juzolaz@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','juzolaz@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','juzolaz','display_name','Juzolaz'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'juzolaz','Juzolaz','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='teemysamson144@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','teemysamson144@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','teemysamson144','display_name','Teemysamson'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'teemysamson144','Teemysamson','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='unmaskedcomedy@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','unmaskedcomedy@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','unmaskedcomedy','display_name','Unmaskedcomedy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'unmaskedcomedy','Unmaskedcomedy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='awoleyeprecious41@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','awoleyeprecious41@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','awoleyeprecious41','display_name','Awoleyeprecious'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'awoleyeprecious41','Awoleyeprecious','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dariusibekwe1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dariusibekwe1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dariusibekwe1','display_name','Dariusibekwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dariusibekwe1','Dariusibekwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jareddavies890@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jareddavies890@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jareddavies890','display_name','Jareddavies'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jareddavies890','Jareddavies','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelelewononi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelelewononi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelelewononi','display_name','Samuelelewononi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelelewononi','Samuelelewononi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sammytope6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sammytope6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sammytope6','display_name','Sammytope'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sammytope6','Sammytope','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='boluwatised@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','boluwatised@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','boluwatised','display_name','Boluwatised'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'boluwatised','Boluwatised','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joyibezim31@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joyibezim31@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joyibezim31','display_name','Joyibezim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joyibezim31','Joyibezim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wizzymikky521@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wizzymikky521@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wizzymikky521','display_name','Wisdom Michael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wizzymikky521','Wisdom Michael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oghoghorieakpevwe@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oghoghorieakpevwe@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oghoghorieakpevwe','display_name','Oghoghorieakpevwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oghoghorieakpevwe','Oghoghorieakpevwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akintundeifeoluwa612@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akintundeifeoluwa612@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akintundeifeoluwa612','display_name','Akintundeifeoluwa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akintundeifeoluwa612','Akintundeifeoluwa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='roroyoung209@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','roroyoung209@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','roroyoung209','display_name','Roroyoung'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'roroyoung209','Roroyoung','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='thechibozz@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','thechibozz@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','thechibozz','display_name','Thechibozz'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'thechibozz','Thechibozz','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelokitor7@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelokitor7@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelokitor7','display_name','Noob Tiktok'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelokitor7','Noob Tiktok','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dinakehinde12@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dinakehinde12@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dinakehinde12','display_name','Kehinde Dina'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dinakehinde12','Kehinde Dina','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='silverlord055@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','silverlord055@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','silverlord055','display_name','Silverlord'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'silverlord055','Silverlord','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dchidesco@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dchidesco@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dchidesco','display_name','Dchidesco'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dchidesco','Dchidesco','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='amosisaleye@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','amosisaleye@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','amosisaleye','display_name','Amosisaleye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'amosisaleye','Amosisaleye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='victoroyebanji39@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','victoroyebanji39@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','victoroyebanji39','display_name','Victoroyebanji'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'victoroyebanji39','Victoroyebanji','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='uchechukwus847@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','uchechukwus847@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','uchechukwus847','display_name','Samuel Uchechukwu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'uchechukwus847','Samuel Uchechukwu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sourabhmrfr19@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sourabhmrfr19@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sourabhmrfr19','display_name','Sourabhmrfr'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sourabhmrfr19','Sourabhmrfr','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='muolokwuabuchi@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','muolokwuabuchi@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','muolokwuabuchi','display_name','Muolokwuabuchi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'muolokwuabuchi','Muolokwuabuchi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kryelltiger@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kryelltiger@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kryelltiger','display_name','Kryelltiger'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kryelltiger','Kryelltiger','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gabg83226@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gabg83226@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gabg83226','display_name','Gabg'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gabg83226','Gabg','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='efeahwayievu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','efeahwayievu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','efeahwayievu','display_name','Efeahwayievu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'efeahwayievu','Efeahwayievu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='marvinwilla0@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','marvinwilla0@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','marvinwilla0','display_name','Marvinwilla'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'marvinwilla0','Marvinwilla','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='pelumia602@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','pelumia602@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','pelumia602','display_name','Pelumi Idowu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'pelumia602','Pelumi Idowu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='lekank331@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','lekank331@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','lekank331','display_name','Ola Lekzy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'lekank331','Ola Lekzy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='georgealabi568@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','georgealabi568@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','georgealabi568','display_name','Georgealabi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'georgealabi568','Georgealabi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nzubemnwoye@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nzubemnwoye@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nzubemnwoye','display_name','Nzubemnwoye'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nzubemnwoye','Nzubemnwoye','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='afolabiayom@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','afolabiayom@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','afolabiayom','display_name','Afolabiayom'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'afolabiayom','Afolabiayom','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tofeyinti89@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tofeyinti89@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tofeyinti89','display_name','Tofeyinti'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tofeyinti89','Tofeyinti','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michael08153@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michael08153@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michael08153','display_name','Michael Peter'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michael08153','Michael Peter','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='veersparo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','veersparo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','veersparo','display_name','Veersparo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'veersparo','Veersparo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chukwuemekaignatius111@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chukwuemekaignatius111@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chukwuemekaignatius111','display_name','Chukwuemekaignatius'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chukwuemekaignatius111','Chukwuemekaignatius','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='danieldamilola494@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','danieldamilola494@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','danieldamilola494','display_name','Danieldamilola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'danieldamilola494','Danieldamilola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ariagiegbeemmanuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ariagiegbeemmanuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ariagiegbeemmanuel','display_name','Emmanuel ARIAGIEGBE'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ariagiegbeemmanuel','Emmanuel ARIAGIEGBE','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dukehound181@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dukehound181@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dukehound181','display_name','Dukehound'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dukehound181','Dukehound','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='yusufsuleimanezhin@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','yusufsuleimanezhin@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','yusufsuleimanezhin','display_name','Yusufsuleimanezhin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'yusufsuleimanezhin','Yusufsuleimanezhin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='umaryore08@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','umaryore08@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','umaryore08','display_name','Umaryore'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'umaryore08','Umaryore','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ibekwedarius45@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ibekwedarius45@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ibekwedarius45','display_name','Darius Ibekwe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ibekwedarius45','Darius Ibekwe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='wilsonpresley850@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','wilsonpresley850@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','wilsonpresley850','display_name','Wilsonpresley'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'wilsonpresley850','Wilsonpresley','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='enyiaisrael@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','enyiaisrael@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','enyiaisrael','display_name','Enyiaisrael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'enyiaisrael','Enyiaisrael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelsobo99@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelsobo99@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelsobo99','display_name','Emmanuelsobo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelsobo99','Emmanuelsobo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='satarbabs23@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','satarbabs23@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','satarbabs23','display_name','Satarbabs'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'satarbabs23','Satarbabs','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olashinamuhammed22@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olashinamuhammed22@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olashinamuhammed22','display_name','Olashinamuhammed'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olashinamuhammed22','Olashinamuhammed','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bricksbenjamin61@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bricksbenjamin61@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bricksbenjamin61','display_name','Bricksbenjamin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bricksbenjamin61','Bricksbenjamin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ifechukwuuwagba6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ifechukwuuwagba6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ifechukwuuwagba6','display_name','Ifechukwu Uwagba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ifechukwuuwagba6','Ifechukwu Uwagba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='stanleychika113@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','stanleychika113@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','stanleychika113','display_name','Stanleychika'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'stanleychika113','Stanleychika','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nicolecopeland001@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nicolecopeland001@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nicolecopeland001','display_name','Nicolecopeland'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nicolecopeland001','Nicolecopeland','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bertcal37@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bertcal37@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bertcal37','display_name','Bertcal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bertcal37','Bertcal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='erosenpai8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','erosenpai8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','erosenpai8','display_name','Ero Senpai'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'erosenpai8','Ero Senpai','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='beeplaysmlbb@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','beeplaysmlbb@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','beeplaysmlbb','display_name','Ibrahim Lawal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'beeplaysmlbb','Ibrahim Lawal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dickydiorpablo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dickydiorpablo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dickydiorpablo','display_name','Dickydiorpablo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dickydiorpablo','Dickydiorpablo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kohworeuben6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kohworeuben6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kohworeuben6','display_name','Kohworeuben'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kohworeuben6','Kohworeuben','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='victoregwuhness@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','victoregwuhness@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','victoregwuhness','display_name','Victoregwuhness'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'victoregwuhness','Victoregwuhness','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='omodamwenfelicia6@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','omodamwenfelicia6@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','omodamwenfelicia6','display_name','Omodamwenfelicia'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'omodamwenfelicia6','Omodamwenfelicia','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='anidaniel1832@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','anidaniel1832@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','anidaniel1832','display_name','Anidaniel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'anidaniel1832','Anidaniel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='100eldorado265@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','100eldorado265@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','100eldorado265','display_name','El Dorado'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'100eldorado265','El Dorado','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='danielikechukwu2012@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','danielikechukwu2012@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','danielikechukwu2012','display_name','Daniel Ovat'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'danielikechukwu2012','Daniel Ovat','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='rikelmemenezes38@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','rikelmemenezes38@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','rikelmemenezes38','display_name','Rikelmemenezes'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'rikelmemenezes38','Rikelmemenezes','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dmassaquoi44@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dmassaquoi44@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dmassaquoi44','display_name','Dmassaquoi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dmassaquoi44','Dmassaquoi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='floof2580@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','floof2580@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','floof2580','display_name','Floof'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'floof2580','Floof','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='hadebanjo777@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','hadebanjo777@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','hadebanjo777','display_name','Hadebanjo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'hadebanjo777','Hadebanjo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='destruc3803l@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','destruc3803l@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','destruc3803l','display_name','Destruc L'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'destruc3803l','Destruc L','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='obiokoyedelight@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','obiokoyedelight@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','obiokoyedelight','display_name','Obiokoyedelight'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'obiokoyedelight','Obiokoyedelight','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='uchechic33@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','uchechic33@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','uchechic33','display_name','Uchechic'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'uchechic33','Uchechic','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kelvincharlesnd@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kelvincharlesnd@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kelvincharlesnd','display_name','Kelvincharlesnd'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kelvincharlesnd','Kelvincharlesnd','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='mayowabsq28@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','mayowabsq28@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','mayowabsq28','display_name','Mayowabsq'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'mayowabsq28','Mayowabsq','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='jq784040@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','jq784040@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','jq784040','display_name','Jq'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'jq784040','Jq','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='marjormarineltd@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','marjormarineltd@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','marjormarineltd','display_name','Marjormarineltd'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'marjormarineltd','Marjormarineltd','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='emmanuelekigho@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','emmanuelekigho@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','emmanuelekigho','display_name','Emmanuel Ekigho'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'emmanuelekigho','Emmanuel Ekigho','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='princewillanyaogu4@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','princewillanyaogu4@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','princewillanyaogu4','display_name','Princewillanyaogu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'princewillanyaogu4','Princewillanyaogu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babatundeemmanuel8599@gamil.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babatundeemmanuel8599@gamil.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babatundeemmanuel8599','display_name','Babatundeemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babatundeemmanuel8599','Babatundeemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ilorieniola517@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ilorieniola517@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ilorieniola517','display_name','Ilorieniola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ilorieniola517','Ilorieniola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gideonola2006@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gideonola2006@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gideonola2006','display_name','Gideon Ola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gideonola2006','Gideon Ola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okunnua.m@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okunnua.m@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okunnuam','display_name','Okunnua M'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okunnuam','Okunnua M','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='johnjustice112@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','johnjustice112@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','johnjustice112','display_name','Johnjustice'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'johnjustice112','Johnjustice','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samuelkolade45@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samuelkolade45@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samuelkolade45','display_name','Samuelkolade'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samuelkolade45','Samuelkolade','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bernardbakare@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bernardbakare@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bernardbakare','display_name','Bernardbakare'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bernardbakare','Bernardbakare','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='agadasunday451@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','agadasunday451@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','agadasunday451','display_name','Agada Sunday'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'agadasunday451','Agada Sunday','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='efeturiokeoghene2@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','efeturiokeoghene2@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','efeturiokeoghene2','display_name','Efeturiokeoghene'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'efeturiokeoghene2','Efeturiokeoghene','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ciscojoshua397@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ciscojoshua397@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ciscojoshua397','display_name','Cisco Joshua'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ciscojoshua397','Cisco Joshua','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='eniolataiwo479@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','eniolataiwo479@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','eniolataiwo479','display_name','Eniola Taiwo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'eniolataiwo479','Eniola Taiwo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='derryscott18@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','derryscott18@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','derryscott18','display_name','Derry Official'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'derryscott18','Derry Official','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sickledemon1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sickledemon1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sickledemon1','display_name','Sickledemon'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sickledemon1','Sickledemon','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='exoduscaleb18@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','exoduscaleb18@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','exoduscaleb18','display_name','Caleb Exodus'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'exoduscaleb18','Caleb Exodus','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='evacharity704@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','evacharity704@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','evacharity704','display_name','Evacharity'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'evacharity704','Evacharity','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='obideword2020@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','obideword2020@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','obideword2020','display_name','Obideword'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'obideword2020','Obideword','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='goodystan5@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','goodystan5@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','goodystan5','display_name','Goodystan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'goodystan5','Goodystan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='izuchukwuekeneeze20@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','izuchukwuekeneeze20@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','izuchukwuekeneeze20','display_name','Izuchukwuekeneeze'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'izuchukwuekeneeze20','Izuchukwuekeneeze','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='okeogheneissachar@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','okeogheneissachar@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','okeogheneissachar','display_name','Okeogheneissachar'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'okeogheneissachar','Okeogheneissachar','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chikwenducalebify@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chikwenducalebify@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chikwenducalebify','display_name','Chikwenducalebify'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chikwenducalebify','Chikwenducalebify','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chrisrosebud259@gmal.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chrisrosebud259@gmal.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chrisrosebud259','display_name','Chris Rosebud'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chrisrosebud259','Chris Rosebud','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gabbieriel012@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gabbieriel012@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gabbieriel012','display_name','Gabbieriel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gabbieriel012','Gabbieriel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='loverboyog83@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','loverboyog83@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','loverboyog83','display_name','Loverboyog'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'loverboyog83','Loverboyog','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulrahmonayinla76@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulrahmonayinla76@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulrahmonayinla76','display_name','Abdulrahmonayinla'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulrahmonayinla76','Abdulrahmonayinla','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fortwayne2006@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fortwayne2006@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fortwayne2006','display_name','Fortwayne'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fortwayne2006','Fortwayne','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tonyk6382@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tonyk6382@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tonyk6382','display_name','TERLUMUN KENNETH'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tonyk6382','TERLUMUN KENNETH','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abonemmanuel1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abonemmanuel1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abonemmanuel1','display_name','Abonemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abonemmanuel1','Abonemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ellab8713@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ellab8713@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ellab8713','display_name','Ellab'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ellab8713','Ellab','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='samteemy144@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','samteemy144@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','samteemy144','display_name','Awotedu Oladipupo'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'samteemy144','Awotedu Oladipupo','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fahozandaudadelakun01@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fahozandaudadelakun01@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fahozandaudadelakun01','display_name','Fahozan Adelakun'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fahozandaudadelakun01','Fahozan Adelakun','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ikogeephraim1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ikogeephraim1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ikogeephraim1','display_name','Ikogeephraim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ikogeephraim1','Ikogeephraim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chibuezeog32@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chibuezeog32@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chibuezeog32','display_name','Chibuezeog'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chibuezeog32','Chibuezeog','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='divinegiftamarachukwu@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','divinegiftamarachukwu@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','divinegiftamarachukwu','display_name','Divinegiftamarachukwu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'divinegiftamarachukwu','Divinegiftamarachukwu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davincent078@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davincent078@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davincent078','display_name','David Vincent'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davincent078','David Vincent','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arikearike666@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arikearike666@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arikearike666','display_name','Arikearike'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arikearike666','Arikearike','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidelue57@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidelue57@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidelue57','display_name','Davidelue'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidelue57','Davidelue','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bluestorm9821@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bluestorm9821@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bluestorm9821','display_name','Bluestorm'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bluestorm9821','Bluestorm','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='luckychidera51@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','luckychidera51@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','luckychidera51','display_name','Luckychidera'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'luckychidera51','Luckychidera','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ee6016405@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ee6016405@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ee6016405','display_name','Ee'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ee6016405','Ee','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='henrycoder20@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','henrycoder20@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','henrycoder20','display_name','Henrycoder'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'henrycoder20','Henrycoder','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='israelikani954@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','israelikani954@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','israelikani954','display_name','Isreal David'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'israelikani954','Isreal David','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='malikkadir5566@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','malikkadir5566@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','malikkadir5566','display_name','Malikkadir'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'malikkadir5566','Malikkadir','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='oluwakayodeoluwatobiloba1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','oluwakayodeoluwatobiloba1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','oluwakayodeoluwatobiloba1','display_name','Oluwakayodeoluwatobiloba'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'oluwakayodeoluwatobiloba1','Oluwakayodeoluwatobiloba','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='odunright19@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','odunright19@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','odunright19','display_name','Odunright'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'odunright19','Odunright','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fchibueze444@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fchibueze444@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fchibueze444','display_name','Fchibueze'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fchibueze444','Fchibueze','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tochexgaming1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tochexgaming1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tochexgaming1','display_name','Tochex Games'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tochexgaming1','Tochex Games','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tiflexmicheal@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tiflexmicheal@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tiflexmicheal','display_name','Tiflexmicheal'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tiflexmicheal','Tiflexmicheal','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kksmk08@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kksmk08@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kksmk08','display_name','Kksmk'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kksmk08','Kksmk','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='pleaseofa@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','pleaseofa@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','pleaseofa','display_name','Pleaseofa'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'pleaseofa','Pleaseofa','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='controller164@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','controller164@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','controller164','display_name','Controller'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'controller164','Controller','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tomiwaoguntola40@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tomiwaoguntola40@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tomiwaoguntola40','display_name','Tomiwa Oguntola'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tomiwaoguntola40','Tomiwa Oguntola','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abonemmanuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abonemmanuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abonemmanuel','display_name','Abonemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abonemmanuel','Abonemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bace9894@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bace9894@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bace9894','display_name','VICTOR ADETILOYE'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bace9894','VICTOR ADETILOYE','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='whitejoshua2005@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','whitejoshua2005@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','whitejoshua2005','display_name','Whitejoshua'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'whitejoshua2005','Whitejoshua','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='milliyoung231@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','milliyoung231@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','milliyoung231','display_name','Milliyoung'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'milliyoung231','Milliyoung','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tobiabioduncharles@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tobiabioduncharles@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tobiabioduncharles','display_name','Tobiabioduncharles'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tobiabioduncharles','Tobiabioduncharles','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='luisdrunk358@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','luisdrunk358@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','luisdrunk358','display_name','Divine Favour'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'luisdrunk358','Divine Favour','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='kingtka361@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','kingtka361@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','kingtka361','display_name','Kingtka'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'kingtka361','Kingtka','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='sadikgwandu73@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','sadikgwandu73@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','sadikgwandu73','display_name','Sadikgwandu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'sadikgwandu73','Sadikgwandu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babsabayomi84@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babsabayomi84@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babsabayomi84','display_name','Ghost Gang'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babsabayomi84','Ghost Gang','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babatundeemmanuel8599@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babatundeemmanuel8599@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babatundeemmanuel85991','display_name','Babatundeemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babatundeemmanuel85991','Babatundeemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akintundeopeyemi001@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akintundeopeyemi001@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akintundeopeyemi001','display_name','Akintunde Opeyemi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akintundeopeyemi001','Akintunde Opeyemi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='saniyoprecious8@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','saniyoprecious8@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','saniyoprecious8','display_name','Saniyoprecious'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'saniyoprecious8','Saniyoprecious','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ainabosetaiwo@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ainabosetaiwo@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ainabosetaiwo','display_name','Ayinde Usman'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ainabosetaiwo','Ayinde Usman','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nwadishimichael488@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nwadishimichael488@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nwadishimichael488','display_name','Nwadishimichael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nwadishimichael488','Nwadishimichael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akanniemma@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akanniemma@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akanniemma','display_name','Emmanuel Akanni'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akanniemma','Emmanuel Akanni','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='osukamichael514@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','osukamichael514@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','osukamichael514','display_name','Osukamichael'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'osukamichael514','Osukamichael','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='babatundeemmanuel@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','babatundeemmanuel@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','babatundeemmanuel','display_name','Babatundeemmanuel'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'babatundeemmanuel','Babatundeemmanuel','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='chinedunwoke366@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','chinedunwoke366@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','chinedunwoke366','display_name','Chinedunwoke'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'chinedunwoke366','Chinedunwoke','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fffboy321@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fffboy321@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fffboy321','display_name','Fffboy'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fffboy321','Fffboy','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='arinzedavid374@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','arinzedavid374@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','arinzedavid374','display_name','Arinzedavid'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'arinzedavid374','Arinzedavid','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='enyeobidivinegift@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','enyeobidivinegift@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','enyeobidivinegift','display_name','Enyeobidivinegift'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'enyeobidivinegift','Enyeobidivinegift','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='volarmec@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','volarmec@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','volarmec','display_name','Volarmec'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'volarmec','Volarmec','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='davidmassaquoi30@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','davidmassaquoi30@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','davidmassaquoi30','display_name','Davidmassaquoi'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'davidmassaquoi30','Davidmassaquoi','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='q4716831@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','q4716831@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','q4716831','display_name','Q'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'q4716831','Q','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='raph207zack@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','raph207zack@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','raph207zack','display_name','Raphael Zack'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'raph207zack','Raphael Zack','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='efegodswill10@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','efegodswill10@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','efegodswill10','display_name','Efe Godswill'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'efegodswill10','Efe Godswill','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='odibomaghan@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','odibomaghan@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','odibomaghan','display_name','Odibomaghan'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'odibomaghan','Odibomaghan','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='ninaokoroafor@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','ninaokoroafor@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','ninaokoroafor','display_name','Nina Okoroafor'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'ninaokoroafor','Nina Okoroafor','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nathanboadu366@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nathanboadu366@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nathanboadu366','display_name','Nathan Boadu'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nathanboadu366','Nathan Boadu','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='xtreme.gamerj1@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','xtreme.gamerj1@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','xtremegamerj1','display_name','JOSEPH GABRIEL'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'xtremegamerj1','JOSEPH GABRIEL','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='dvibe1468@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','dvibe1468@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','dvibe1468','display_name','Abdulfatai Ibrahim'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'dvibe1468','Abdulfatai Ibrahim','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='osagieirabor798@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','osagieirabor798@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','osagieirabor798','display_name','Irabor'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'osagieirabor798','Irabor','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='akinloyebasit40@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','akinloyebasit40@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','akinloyebasit40','display_name','Akinloye Basit'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'akinloyebasit40','Akinloye Basit','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='paoyeanleng@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','paoyeanleng@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','paoyeanleng','display_name','PAV YEAN Leng'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'paoyeanleng','PAV YEAN Leng','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='olaigbeanjola96@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','olaigbeanjola96@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','olaigbeanjola96','display_name','Anjola Olaigbe'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'olaigbeanjola96','Anjola Olaigbe','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='joyceroberts111@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','joyceroberts111@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','joyceroberts111','display_name','Emmanuel Roberts'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'joyceroberts111','Emmanuel Roberts','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='abdulrahmansalaudeen007@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','abdulrahmansalaudeen007@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','abdulrahmansalaudeen007','display_name','Abdulrahmansalaudeen'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'abdulrahmansalaudeen007','Abdulrahmansalaudeen','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='nnannagodhand@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','nnannagodhand@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','nnannagodhand','display_name','nnanna God hand'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'nnannagodhand','nnanna God hand','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='omalejoe0@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','omalejoe0@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','omalejoe0','display_name','Great Joseph'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'omalejoe0','Great Joseph','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='smartd833@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','smartd833@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','smartd833','display_name','Smartd'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'smartd833','Smartd','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='fifoluwaadams@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','fifoluwaadams@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','fifoluwaadams','display_name','Fifoluwa Sule-adams'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'fifoluwaadams','Fifoluwa Sule-adams','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='michaelogbonna365@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','michaelogbonna365@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','michaelogbonna365','display_name','𝐌𝐢𝐜𝐡𝐚𝐞𝐥 𝐆𝐞𝐨𝐫𝐠𝐞'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'michaelogbonna365','𝐌𝐢𝐜𝐡𝐚𝐞𝐥 𝐆𝐞𝐨𝐫𝐠𝐞','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='bennyabah321@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','bennyabah321@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','bennyabah321','display_name','Bennyabah'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'bennyabah321','Bennyabah','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='megawolves233@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','megawolves233@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','megawolves233','display_name','Megawolves'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'megawolves233','Megawolves','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='gloryfrank530@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','gloryfrank530@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','gloryfrank530','display_name','Glory Frank'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'gloryfrank530','Glory Frank','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='tinaamuga55@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','tinaamuga55@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','tinaamuga55','display_name','Promise Benjamin'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'tinaamuga55','Promise Benjamin','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE email='victorchisomezezuma@gmail.com') THEN
    INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token)
    VALUES('00000000-0000-0000-0000-000000000000',gen_random_uuid(),'authenticated','authenticated','victorchisomezezuma@gmail.com','$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',NOW(),'{"provider":"email","providers":["email"]}'::jsonb,jsonb_build_object('username','victorchisomezezuma','display_name','Victor Chisom'),NOW(),NOW(),'','') RETURNING id INTO v_uid;
    INSERT INTO public.profiles(id,username,display_name,role,verification_status,created_at,updated_at) VALUES(v_uid,'victorchisomezezuma','Victor Chisom','user','unverified',NOW(),NOW()) ON CONFLICT(id) DO NOTHING;
  END IF;
END $$;

ALTER TABLE auth.users ENABLE TRIGGER on_auth_user_created;

SELECT 'auth_users' as tbl, COUNT(*) as count FROM auth.users WHERE role='authenticated'
UNION ALL SELECT 'profiles', COUNT(*) FROM public.profiles;