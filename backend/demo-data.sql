-- Optional, repeatable demo data. Run only after the application has created its schema.
\set ON_ERROR_STOP on
BEGIN;
SELECT pg_advisory_xact_lock(86190304);
CREATE TABLE IF NOT EXISTS demo_seed_history (
  seed_key VARCHAR(100) PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
DECLARE
  request_id BIGINT;
  procedure_id BIGINT;
  offer_id BIGINT;
  result_id BIGINT;
  contract_id BIGINT;
  document_id BIGINT;
  i INTEGER;
  contract_status TEXT;
  status_list TEXT[] := ARRAY['DRAFT', 'REVIEW', 'REVISION', 'APPROVED', 'ACTIVE', 'CLOSED'];
  subject_list TEXT[] := ARRAY['Поставка ноутбуков', 'Техническое обслуживание принтеров', 'Лицензии офисного ПО', 'Поставка мониторов', 'Обслуживание сети', 'Поставка бумаги'];
BEGIN
  IF EXISTS (SELECT 1 FROM demo_seed_history WHERE seed_key = 'coursework_demo_v1') THEN
    RAISE NOTICE 'Демонстрационный набор уже загружен; данные не изменены.';
    RETURN;
  END IF;

  INSERT INTO purchase_requests(initiator,subject,description,amount,due_date,status) VALUES
    ('initiator','Закупка рабочих станций','Черновик: подготовить рабочие места для новых сотрудников.',250000,CURRENT_DATE+45,'DRAFT'),
    ('initiator','Закупка сетевого оборудования','Заявка ожидает решения руководителя.',180000,CURRENT_DATE+50,'REVIEW'),
    ('initiator','Поставка расходных материалов','Согласованная заявка готова к созданию процедуры.',65000,CURRENT_DATE+35,'APPROVED');
  INSERT INTO purchase_requests(initiator,subject,description,amount,due_date,status,comment)
    VALUES ('initiator','Обновление мебели','Заявка возвращена для уточнения количества.',120000,CURRENT_DATE+60,'REVISION','Укажите количество рабочих мест.');

  -- Three open procedures demonstrate different decisions and supplier actions.
  FOR i IN 1..3 LOOP
    INSERT INTO purchase_requests(initiator,subject,description,amount,due_date,status)
      VALUES ('initiator', (ARRAY['Поставка периферии','Поставка офисной техники','Обслуживание оборудования'])[i],
              'Согласованная заявка для демонстрационной закупки.',100000+i*20000,CURRENT_DATE+55,'APPROVED')
      RETURNING id INTO request_id;
    INSERT INTO procedures(request_id,title,conditions,deadline,status)
      VALUES (request_id,(ARRAY['Поставка периферии','Поставка офисной техники','Обслуживание оборудования'])[i],
              'Поставка и сопровождение по условиям организации.',CURRENT_DATE+14+i,'OPEN') RETURNING id INTO procedure_id;
    IF i = 1 THEN
      INSERT INTO offers(procedure_id,supplier,price,terms,status,review_state,comment) VALUES
        (procedure_id,'supplier1',85000,'Поставка в течение 10 дней.','UNDER_REVIEW',NULL,NULL),
        (procedure_id,'supplier2',91000,'Поставка в течение 7 дней.','UNDER_REVIEW','PENDING','Просьба согласовать допуск.');
    ELSIF i = 2 THEN
      INSERT INTO offers(procedure_id,supplier,price,terms,status,comment,clarification_deadline) VALUES
        (procedure_id,'supplier1',95000,'Поставка с гарантией 12 месяцев.','NEED_INFO','Уточните срок поставки.',CURRENT_TIMESTAMP+INTERVAL '4 days');
      INSERT INTO offers(procedure_id,supplier,price,terms,status,review_state) VALUES
        (procedure_id,'supplier2',98000,'Поставка в течение 14 дней.','ACCEPTED','APPROVED');
      INSERT INTO notifications(recipient,message) VALUES ('supplier1','Демонстрационная закупка: уточните срок поставки в карточке предложения.');
    ELSE
      INSERT INTO offers(procedure_id,supplier,price,terms,status,review_state) VALUES
        (procedure_id,'supplier1',110000,'Обслуживание в течение года.','ACCEPTED','APPROVED');
      INSERT INTO offers(procedure_id,supplier,price,terms,status,comment) VALUES
        (procedure_id,'supplier2',135000,'Выезд специалиста по запросу.','REJECTED','Условия не соответствуют требованиям.');
      INSERT INTO notifications(recipient,message) VALUES ('supplier2','Демонстрационное предложение отклонено: условия не соответствуют требованиям.');
    END IF;
  END LOOP;

  -- One completed procedure and result per contract preserves all normal relationships.
  FOR i IN 1..array_length(status_list,1) LOOP
    contract_status := status_list[i];
    INSERT INTO purchase_requests(initiator,subject,description,amount,due_date,status)
      VALUES ('initiator',subject_list[i],'Согласованная заявка; закупка завершена.',100000+i*10000,CURRENT_DATE+60,'APPROVED') RETURNING id INTO request_id;
    INSERT INTO procedures(request_id,title,conditions,deadline,status)
      VALUES (request_id,subject_list[i],'Демонстрационная завершённая закупка.',CURRENT_DATE-10,'COMPLETED') RETURNING id INTO procedure_id;
    INSERT INTO offers(procedure_id,supplier,price,terms,status,review_state)
      VALUES (procedure_id,'supplier1',90000+i*10000,'Учебное предложение выбранного поставщика.','ACCEPTED','APPROVED') RETURNING id INTO offer_id;
    INSERT INTO results(procedure_id,offer_id,outcome,comment)
      VALUES (procedure_id,offer_id,'WINNER','Выбран демонстрационный поставщик.') RETURNING id INTO result_id;
    INSERT INTO contracts(result_id,number,subject,amount,start_date,end_date,status,execution_notes,comment,edo_status,edo_reference,edo_at)
      VALUES (result_id,'DEMO-'||gen_random_uuid()::text,subject_list[i],90000+i*10000,CURRENT_DATE-20,CURRENT_DATE+90,contract_status,
              CASE WHEN contract_status IN ('ACTIVE','CLOSED') THEN 'Учебные сведения об исполнении.' ELSE NULL END,
              CASE WHEN contract_status='REVISION' THEN 'Уточните условия поставки.' ELSE NULL END,
              CASE WHEN contract_status IN ('ACTIVE','CLOSED') THEN 'SIMULATED' ELSE NULL END,
              CASE WHEN contract_status IN ('ACTIVE','CLOSED') THEN 'DEMO-SEED-'||result_id ELSE NULL END,
              CASE WHEN contract_status IN ('ACTIVE','CLOSED') THEN CURRENT_TIMESTAMP ELSE NULL END)
      RETURNING id INTO contract_id;
    INSERT INTO contract_documents(contract_id,version,filename,content_type,content)
      VALUES (contract_id,1,'demo-contract-'||contract_id||'.txt','text/plain',convert_to('Учебный документ договора. Юридической силы не имеет.','UTF8')) RETURNING id INTO document_id;
    IF contract_status = 'REVISION' THEN
      INSERT INTO approvals(contract_id,document_id,actor,decision,comment)
        VALUES (contract_id,document_id,'manager','REVISION','Уточните условия поставки.');
    ELSIF contract_status IN ('APPROVED','ACTIVE','CLOSED') THEN
      INSERT INTO approvals(contract_id,document_id,actor,decision,comment)
        VALUES (contract_id,document_id,'manager','APPROVED','Демонстрационное согласование.');
    END IF;
  END LOOP;
  INSERT INTO demo_seed_history(seed_key) VALUES ('coursework_demo_v1');
  RAISE NOTICE 'Демонстрационные данные добавлены.';
END $$;
COMMIT;
