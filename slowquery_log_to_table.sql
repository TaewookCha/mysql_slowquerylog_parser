/**********************************************************************
-- 2022-01-24 taewookcha : MySQL SlowQueryLog to Table format parser
   -- You can run this script on SQL Server express edition
**********************************************************************/
 
 --#00. Bulk insert to work table
	DROP	TABLE	IF EXISTS #tbl_SlowQuery;
	CREATE	TABLE	#tbl_SlowQuery		(Txt nvarchar(max));

	DROP	TABLE	IF EXISTS #tbl_SlowQueryParse;
	CREATE	TABLE	#tbl_SlowQueryParse (CheckTime_UTC datetime2(6) , UserHost nvarchar(max) , QueryInformation nvarchar(max))

	BULK	INSERT	#tbl_SlowQuery
	FROM	N'D:\mysql-slow-testdb-2022012405.log' --Assign the slow query log file's path


--#01.Set variable value from table
	DECLARE @vTxt nvarchar(max) = N''
	SELECT  @vTxt += Txt FROM #tbl_SlowQuery;

--#02.Remove Slowquery Header	
	SELECT	@vTxt = SUBSTRING(@vTxt,CHARINDEX(N'Time                 Id Command    Argument'+nchar(10),@vTxt,0)+LEN(N'Time                 Id Command    Argument'),999999999)
	--PRINT	@vTxt

--#03.Add Escape for XML
	SELECT	@vTxt = REPLACE(@vTxt,N'"'	,	N'&quot;'	)
	SELECT	@vTxt = REPLACE(@vTxt,N''''	,	N'&apos;'	)
	SELECT	@vTxt = REPLACE(@vTxt,N'<'	,	N'&lt;'		)
	SELECT	@vTxt = REPLACE(@vTxt,N'>'	,	N'&gt;'		)
	SELECT	@vTxt = REPLACE(@vTxt,N'&'	,	N'&amp;'	)

--#04. Parse MySQL slow query log to XML
	SELECT	@vTxt = REPLACE(@vTxt,N'# Time: '					,nchar(9)+N'</Query>'	+nchar(10)+N'</SlowQuery>'	+nchar(10)+N'<SlowQuery>'	+nchar(10)+nchar(9)+N'<Time>')
	SELECT	@vTxt = REPLACE(@vTxt,nchar(10)+N'# User@Host: '	,nchar(9)+N'</Time>'		+ nchar(10)+nchar(9)	+N'<UserHost>')
	SELECT	@vTxt = REPLACE(@vTxt,nchar(10)+N'# Query_time: '	,nchar(9)+N'</UserHost>'	+ nchar(10)+nchar(9)	+N'<Query>')
	SELECT	@vTxt = REPLACE(@vTxt,N'<SlowQuery>'+nchar(10)+N'<SlowQuery>',N'<SlowQuery>')

	SELECT	@vTxt = STUFF(@vTxt,1,24,N'')
	SELECT	@vTxt = @vTxt+nchar(10)+N'</Query></SlowQuery></root>'
	SELECT	@vTxt = N'<root>'+@vTxt
	--PRINT	@vTxt

--#05. Return slowquery table (XML to Table)
	DECLARE @vXML			XML = CAST(@vTxt AS XML)	
	
	INSERT	INTO #tbl_SlowQueryParse
	SELECT	CheckTime_UTC	= SQ.C.value(N'(./Time)[1]'		, N'datetime2(6)')
		,	UserHost		= SQ.C.value(N'(./UserHost)[1]'	, N'nvarchar(max)')
		,	QueryInformation= SQ.C.value(N'(./Query)[1]'	, N'nvarchar(max)')
		--,	SQ.C.query(N'.')
	  FROM	@vXML.nodes(N'/root/SlowQuery') SQ(C)

	SELECT	CheckTime_UTC
		,	UserHost		= TRIM(LEFT(UserHost,CHARINDEX(N' id:',UserHost,1)))
		,	Duration_sec	= CAST(LEFT(QueryInformation, CHARINDEX(N' Lock_time: ',QueryInformation,1)) AS money)
		,	LockTime_sec	= CAST(TRIM(SUBSTRING(QueryInformation, CHARINDEX(N' Lock_time: '    ,QueryInformation,1) +11 , CHARINDEX(N' Rows_sent: '    ,QueryInformation,1) - CHARINDEX(N' Lock_time: '    ,QueryInformation,1) - 10)) AS money)
		,	Rows_sent	    = CAST(TRIM(SUBSTRING(QueryInformation, CHARINDEX(N' Rows_sent: '    ,QueryInformation,1) +11 , CHARINDEX(N' Rows_examined: ',QueryInformation,1) - CHARINDEX(N' Rows_sent: '    ,QueryInformation,1) - 10)) AS money)
		,	Rows_examined   = TRIM(SUBSTRING(QueryInformation, CHARINDEX(N' Rows_examined: ',QueryInformation,1) +15 , CHARINDEX(nchar(10),QueryInformation,CHARINDEX(N' Rows_examined: ',QueryInformation,1)) - CHARINDEX(N' Rows_examined: ',QueryInformation,1) - 15))
		,	Query			= REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									TRIM(SUBSTRING(QueryInformation, CHARINDEX(nchar(10),QueryInformation,CHARINDEX(N' Rows_examined: ',QueryInformation,1)),99999))
									,N'&quot;',N'"'),N'&apos;',N''''),N'&gt;',N'>'),N'&lt;'	,N'<'),N'&amp;',N'&'		
							  )
		--,	QueryInformation
	  FROM	#tbl_SlowQueryParse
	 ORDER	BY
			CheckTime_UTC

--#99. Cleanup
	DROP	TABLE	IF EXISTS #tbl_SlowQueryParse;
	DROP	TABLE	IF EXISTS #tbl_SlowQuery;
