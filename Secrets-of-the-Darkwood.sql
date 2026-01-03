/* Аналитический проект: Исследование поведения пользователей игры «Темнолесье»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * 
*/ 

-- Раздел 1. Исследовательский анализ данных
-- Задание 1. Исследование доли платящих игроков.

-- 1.1 Доля платящих пользователей по всем данным

   SELECT COUNT(id) AS all_users, --- общее количество игроков, зарегистрированных в игре
          SUM(payer) AS user_payer, -- количество платящих игроков
          100.00*ROUND(AVG(payer):: numeric,4) user_payer_share -- доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
   FROM fantasy.users u

   
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

   SELECT race, -- раса персонажа
          SUM(payer) AS user_payer, -- количество платящих игроков
          COUNT(DISTINCT id) AS all_user, -- общее количество зарегистрированных игроков
          100.00*ROUND(AVG(payer):: numeric,4) AS user_payer_share --доля платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа
   FROM fantasy.users u
   INNER JOIN fantasy.race r using(race_id)
   GROUP BY race
   ORDER BY user_payer_share DESC
   
-- Задание 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

   SELECT 
          COUNT(transaction_id) AS count_purchases,
          SUM(amount) AS sum_purchases,
          MIN(amount)::NUMERIC(10, 2) AS min_purchases,
          MIN(amount) FILTER (WHERE amount>0) AS min_purchases_without_zero, --- поиск min, при сключении 0.
          MAX(amount)::NUMERIC(10, 2) AS max_purchases,
          AVG(amount)::NUMERIC(20, 2) AS avg_purchases,
          percentile_disc(0.50) WITHIN GROUP (ORDER BY amount)::NUMERIC(10, 2) AS mediana_purchases,
          STDDEV(amount) ::NUMERIC(10, 4)  AS stddev_purchases
   FROM fantasy.events 
   
-- 2.2. Исследование аномальных покупок.
    SELECT COUNT(amount) FILTER (WHERE amount=0) AS count_zero_amount, ---абсолютное количество нулевых значений
           COUNT(amount) AS count_purchases, -- общее количество покупок
           100.00*ROUND(COUNT(amount) FILTER (WHERE amount=0)::decimal/COUNT(amount),4) AS count_zero_amount_share -- доля нулевых значений в общем количестве
    FROM fantasy.events 
    
   --- определим, что за предметы имели нулевую стоимость
    SELECT  e.item_code,
			i.game_items,
			COUNT(e.item_code)              -- Предметы проданные по стоимости 0
	FROM fantasy.events AS e
	JOIN fantasy.items AS i USING(item_code)
	WHERE e.amount=0
	GROUP BY e.item_code, i.game_items;
				

    
-- 2.3. Сравнительный анализ активности платящих и неплатящих игроков.
-- добавлен расчет показателей с использованием CTE
WITH tb_purchases_data AS ( SELECT id AS id_player,
                                COUNT(*) AS count_purchases,
                                SUM(amount) AS sum_purchases
                         FROM fantasy.events e
                         WHERE amount>0
                         GROUP BY id)
SELECT CASE 
              WHEN u.payer = 1 THEN 'Платящий'
         	  ELSE 'Неплатящий'
         END AS users_category,
         COUNT(DISTINCT pd.id_player) AS amount_player,
         AVG(pd.count_purchases) ::NUMERIC(10, 2) AS avg_count_purchases,
         AVG(pd.sum_purchases)::NUMERIC(10, 2) AS avg_sum_purchases
   FROM fantasy.users AS u
   LEFT JOIN tb_purchases_data AS pd ON  u.id = pd.id_player
   GROUP BY users_category
   
----Сравнительный анализ активности платящих и неплатящих игроков в разрезе рас:
WITH tb_purchases_data AS ( SELECT id AS id_player,
                                COUNT(*) AS count_purchases,
                                SUM(amount) AS sum_purchases
                         FROM fantasy.events e
                         WHERE amount>0
                         GROUP BY id)
SELECT CASE 
              WHEN u.payer = 1 THEN 'Платящий'
         	  ELSE 'Неплатящий'
         END AS users_category,
	     r.race AS race_name,
         COUNT(DISTINCT pd.id_player) AS amount_player,
         AVG(pd.count_purchases) ::NUMERIC(10, 2) AS avg_count_purchases,
         AVG(pd.sum_purchases)::NUMERIC(10, 2) AS avg_sum_purchases
   FROM fantasy.race r 
   LEFT JOIN fantasy.users AS u using(race_id)
   LEFT JOIN tb_purchases_data AS pd ON  u.id = pd.id_player
   GROUP BY users_category,r.race 
   
   
-- 2.4. Исследование популярных эпические предметы.

--- общее количество продаж, общую сумму продаж и количество уникальных покупателей для каждого предмета 
WITH tb_total_purchases AS (SELECT i.item_code,
                                   i.game_items,
								   COUNT(DISTINCT id) AS unique_users,
								   COUNT(transaction_id) AS total_purchases,
								   SUM(amount) AS total_amount
							FROM  fantasy.items i 
							LEFT JOIN fantasy.events AS e USING (item_code)
							WHERE amount>0
							GROUP BY item_code,game_items),
tb_total_sales AS ( SELECT 
                       SUM(total_purchases) AS overall_sales_count
                   FROM tb_total_purchases),
-- общее количество игроков, ограничееное  1 млн.человек
tb_total_player AS  (SELECT 
                           LEAST(COUNT(id), 1000000) AS total_players
                    FROM fantasy.users u)
SELECT tp.item_code,
	   tp.game_items,
	   tp.unique_users,
	   tp.total_purchases,
       tp.total_amount,
	   (100.00 * tp.total_purchases::decimal/(ts.overall_sales_count))::NUMERIC(10, 2) AS items_ratio,
	   (100.00 * tp.unique_users :: decimal/ tpr.total_players) ::NUMERIC(10, 2) AS unique_users_ratio
FROM  tb_total_purchases AS tp 
CROSS JOIN tb_total_sales AS ts,
           tb_total_player AS tpr
ORDER BY total_purchases DESC 

	
-- Раздел 2. Решение adhoc задач от маркетинговой команды игры «Секреты Темнолесья»
-- Задание 1. Исследование зависимость активности игроков от расы персонажа.

-- Для каждой расы считаем количество зарегистрированных пользователей.
WITH tb_total_users AS (SELECT race_id,
						       COUNT(DISTINCT id) AS total_users
						FROM fantasy.users u 
						GROUP BY race_id),
--  количество игроков, которые совершают внутриигровые покупки и количество платящих клиентов;
	tb_total_buyer AS ( SELECT race_id,
						  COUNT(DISTINCT id) FILTER (WHERE amount>0)  AS  total_purchaser, -- количество совершивших покупку
						  COUNT(DISTINCT id) FILTER (WHERE payer = 1) AS total_payers -- количество платящих клиентов
			         FROM fantasy.events e
					 LEFT JOIN fantasy.users u using(id)
		             GROUP BY race_id),
--- информацию об активности игроков с учётом расы персонажа								  
   tb_buyer_activity  AS ( SELECT  u.race_id,
                                   AVG(total_count_amount) AS avg_purchases_per_player,
                                   AVG(total_sum_amount) AS avg_total_sum_per_player,
                                   AVG(total_sum_amount)/AVG(total_count_amount) AS avg_purchase_avg_per_player --- внесла корректировку в расчет 
                           FROM( SELECT id,
		                          COUNT(*)AS total_count_amount,
		                          SUM(amount)  AS total_sum_amount
		                    FROM fantasy.events e
                            WHERE amount>0
                            GROUP BY id) AS tb_1
                            LEFT JOIN fantasy.users u USING(id)
                            GROUP BY race_id)
SELECT r.race_id,
       r.race,
       tu.total_users, --- общее количество зарегистрированных игроков
       tb.total_purchaser, --- количество игроков, которые совершают внутриигровые покупки
       COALESCE(tb.total_purchaser, 0)::float / COALESCE(tu.total_users,1) AS purchaser_ratio, -- доля игроков, которые совершают внутриигровые покупки
       COALESCE(tb.total_payers,0)::float / COALESCE(tb.total_purchaser,1) AS paying_ratio, --- доля платящих клиентов
       ROUND(ba.avg_purchases_per_player:: numeric,3) AS avg_purchases_per_player,  -- среднее количество покупок на одного игрока
       ROUND(ba.avg_purchase_avg_per_player:: numeric,3) AS avg_purchase_avg_per_player,  -- средняя стоимость одной покупки
       ROUND(ba.avg_total_sum_per_player:: numeric,3) AS avg_total_sum_per_player-- средняя суммарная стоимость всех покупок на одного игрока
FROM fantasy.race r 
LEFT JOIN tb_total_users AS tu using(race_id)
LEFT JOIN tb_total_buyer AS tb using(race_id)
LEFT JOIN tb_buyer_activity AS ba using(race_id)
ORDER BY purchaser_ratio DESC

-- Задание 2. Изучение частота покупок в игре

--- Рассчитываем интервала между покупками для каждой покупки
WITH tb_puschase_days AS (SELECT 
                              e.id AS user_id,
                              e.date,
                              e.amount,
                              LAG(e.date) OVER (PARTITION BY e.id ORDER BY e.date) AS previous_purchase_date
    				      FROM fantasy.events  e
                         WHERE e.amount > 0 ), -- Исключаем покупки с нулевой стоимостью,
---общее количество покупок и среднее значение по количеству дней между покупками для каждого игрока
tb_purchases AS ( SELECT user_id,
                         COUNT(*) AS total_purchases,
                         AVG(date::date - previous_purchase_date::date)::NUMERIC(10,3) AS avg_days_between
                  FROM  tb_puschase_days    
                  GROUP BY user_id),
--- проводим фильрацию игроков
tb_player_status AS ( SELECT u.id AS user_id,
                             p.total_purchases,
                             p.avg_days_between,
                             u.payer
                      FROM fantasy.users u
                      INNER JOIN tb_purchases AS p ON u.id=p.user_id
                      WHERE p.total_purchases>=25),
--- ранжируем/делим на группы игроков по частоте покупок						  
frequency_purchases AS ( SELECT user_id,
                                total_purchases,
								avg_days_between,
								payer,
                             NTILE(3) OVER(ORDER BY avg_days_between) AS row_frequency --- скорректировала ORDER BY
                       FROM tb_player_status)
SELECT CASE 
	           WHEN row_frequency = 1 THEN 'высокая частота'
	           WHEN row_frequency = 2 THEN 'умеренная частота'
	           WHEN row_frequency = 3 THEN 'низкая частота'
	      END AS purchase_frequency_group,
	      COUNT(DISTINCT user_id) AS total_users,
	      COUNT(DISTINCT user_id) FILTER(WHERE payer = 1) AS total_payer,
	      (COUNT(DISTINCT user_id) FILTER(WHERE payer = 1)/COUNT(DISTINCT user_id)::decimal):: NUMERIC(10,3) AS payer_ratio,
	      AVG(total_purchases):: NUMERIC(10,3) AS avg_amount_per_user, --- среднее количество покупок на одного игрока
	      AVG(avg_days_between) :: NUMERIC(10,3) AS avg_days_between_per_user --- среднее количество дней между покупками на одного игрока
FROM frequency_purchases
GROUP BY purchase_frequency_group
ORDER BY avg_days_between_per_user	      

	   
	  



        



  
								



   
      
       
       
                                    
                                     )
