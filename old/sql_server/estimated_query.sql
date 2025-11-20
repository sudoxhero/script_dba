-- Query que pode ajudar a ver a porcentagem já concluida de uma query, muito util para saber se falta muito para a criação de um index terminar.

-- Abaixo colocar o id da sessão da query que queira monitorar
declare @session_id INT = 56

SELECT node_id,physical_operator_name, SUM(row_count) row_count,
  SUM(estimate_row_count) AS estimate_row_count,
  CAST(SUM(row_count)*100 AS float)/SUM(estimate_row_count)  percent_completed
FROM sys.dm_exec_query_profiles  
WHERE session_id = @session_id
GROUP BY node_id,physical_operator_name  
ORDER BY node_id;
