--1. Выведите названия самолётов, которые имеют менее 50 посадочных мест.
--(именно названия)
select a.model as "Название самолёта"
from aircrafts a 
join seats s on a.aircraft_code =s.aircraft_code 
group by a.model 
having count(s.seat_no) < 50



--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
--(на сколько процентов ежемесячно происходит изменение, 3 строки, 5 практика - через оконную функцию)

select date_trunc('month', book_date::date) as "Месяц", sum(total_amount) as "Сумма ежемесячной брони", 
(sum(total_amount) - lag(sum(total_amount), 1) over (order by date_trunc('month', book_date::date)))as "Ежемесячная разница",
round((sum(total_amount) - lag(sum(total_amount), 1) over (order by date_trunc('month', book_date::date)))/
lag(sum(total_amount), 1) over (order by date_trunc('month', book_date::date))*100,2) as "Ежемесячное процентное изменение"
from bookings  
group by date_trunc('month', book_date::date)



--3. Выведите названия самолётов без бизнес-класса. Используйте в решении функцию array_agg.
--(работаем только с бизнес-классом! речь про кресла бизнеса, не про тарифы)

select t.model as "Название самолёта"
from 
   (select a.model, array_agg(distinct s.fare_conditions)
    from aircrafts a 
    join seats s on a.aircraft_code = s.aircraft_code
    group by a.aircraft_code)t
where 'Business' <> all(t.array_agg)



--4. Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день. 
--Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
--Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.
--(cte,подзапрос, 1 задание - 1 запрос. Только пустые самолёты! Накопление по каждому аэропорту, на каждый день!)
-- не нужно использовать левые таблицы! 4330 строк)


select z.departure_airport, z.actual_departure, z."Количество мест",
sum(z."Количество мест")over (partition by z.departure_airport,z.actual_departure::date order by z.actual_departure) as "Сумма мест" 
from
 (select  x.departure_airport, x.actual_departure ,
  count(x.aircraft_code)over (partition by x.departure_airport,x.actual_departure::date) as "Количество самолётов",
  x."Количество мест"
  from
    (select f.departure_airport, f.actual_departure, f.aircraft_code, y."Количество мест"
     from flights f
     join (select s.aircraft_code, count(s.seat_no) as "Количество мест"
          from seats s
          group by s.aircraft_code)y on f.aircraft_code = y.aircraft_code
     left join boarding_passes bp  on f.flight_id = bp.flight_id
     where f.actual_departure is not null and bp.boarding_no is null
     group by f.flight_id, y."Количество мест")x
    )z
where z."Количество самолётов">1



--5. Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. 
--Выведите в результат названия аэропортов и процентное отношение!!!!!
--Используйте в решении оконную функцию.
--(ни cte,ни подзапрос - только один запрос с оконной функцией. Маршрут - А до Б. Рейс - из А в Б один путь.)

select t."Пункт А", a2.airport_name as "Пункт Б", t."Процентное соотношение"
from
   (select distinct departure_airport, arrival_airport, a.airport_name as "Пункт А",
    round(count(flight_no)over (partition by departure_airport,arrival_airport)::numeric(4,1)/ count(flight_no)over ()* 100,2)
    as "Процентное соотношение"
    from flights f
    join airports a on f.departure_airport = a.airport_code
    order by departure_airport, arrival_airport)t
join airports a2 on t.arrival_airport = a2.airport_code 



--6. Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7
--(разобраться в каком типе данных значение, обработать и вывести!)

select count(t2.passenger_id), t2."Код телефона"
from
   (select passenger_id , passenger_name, 
    substring(t."Номер телефона" from 3 for 3) as "Код телефона"
    from 
               (select passenger_id , passenger_name, contact_data ->> 'phone' as "Номер телефона"
               from   tickets)t
    )t2
group by t2."Код телефона"



--7. Классифицируйте финансовые обороты (сумму стоимости билетов) по маршрутам:
--до 50 млн – low
--от 50 млн включительно до 150 млн – middle
--от 150 млн включительно – high
--Выведите в результат количество маршрутов в каждом полученном классе.
--(3 строки с кол-ом маршрутов в каждом классе. внимательно, в базе 2 стоимости. 
--Чтобы посчитать стоимость билета, нужно сложить стоимость всех рейсов
-- Либо стоимость разового перелёта в БД - аналогия была в практике - case)

select t."Класс фин.оборотов" , 
count(t.departure_airport) as "Количество маршрутов"
from
     (
      select f.departure_airport , f.arrival_airport , sum(tf.amount) as "Стоимость билетов по маршрутам",
         CASE
           WHEN sum(tf.amount) < 50000000 THEN 'low'
           WHEN sum(tf.amount) >= 50000000 and  sum(tf.amount) < 150000000 THEN 'middle'
           ELSE 'high'
         END "Класс фин.оборотов"
      from flights f 
      join ticket_flights tf on f.flight_id = tf.flight_id 
      group by f.departure_airport , f.arrival_airport 
      )t
group by t."Класс фин.оборотов" 


--8. Вычислите медиану стоимости билетов, медиану стоимости бронирования и отношение медианы бронирования 
--к медиане стоимости билетов, результат округлите до сотых. 
--(нужно использовать функционал, который мы не проходили)
-- 3 стобца, 1 строка, разные виды join

select t."Медиана стоимости билетов", t."Медиана стоимости бронирования", 
round(t."Медиана стоимости бронирования"::numeric/t."Медиана стоимости билетов"::numeric,2) as "Отношение стоимостей"
from
(select *
from 
(select percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) as "Медиана стоимости билетов" from ticket_flights tf) ticket_flights,
(select percentile_cont(0.5) WITHIN GROUP (ORDER BY total_amount) as "Медиана стоимости бронирования" from bookings b) bookings)t


--9. Найдите значение минимальной стоимости одного километра полёта для пассажира. Для этого определите расстояние между аэропортами и учтите стоимость билетов.
--Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. 
--Для работы данного модуля нужно установить ещё один модуль – cube.
--Важно: 
--Установка дополнительных модулей происходит через оператор CREATE EXTENSION название_модуля.
--В облачной базе данных модули уже установлены.
--Функция earth_distance возвращает результат в метрах.
--(для любого пассажира, по всем данным глобально, время 44:00)

select round(min((y."Минимальная стоимость маршрута"::numeric/y."Расстояние между аэропортами км"::numeric)),2) as "Стоимость за км"
from
   (select x.departure_airport, x.arrival_airport,x."Минимальная стоимость маршрута",
    (point(x."lon1", x."lat1")<@>point(x."lon2" , x."lat2")) * 1.609344 as "Расстояние между аэропортами км"
    from
         (select f.departure_airport , a.longitude as "lon1" , a.latitude as "lat1" , 
                 f.arrival_airport , a2.longitude as "lon2" , a2.latitude as "lat2",
                 min(tf.amount) as "Минимальная стоимость маршрута"
          from flights f 
          join airports a on f.departure_airport = a.airport_code 
          join airports a2 on f.arrival_airport = a2.airport_code
          join ticket_flights tf on f.flight_id = tf.flight_id 
          group by f.departure_airport , f.arrival_airport,  
                   a.longitude , a.latitude , a2.longitude, a2.latitude
          )x
     )y
order by "Стоимость за км"
limit 1