
<?php
function CustomLog( $string){
	try{
        $Log_Folder  ='../fileWrite/'.$MainID; 
	   // if(!is_dir($Log_Folder)){
	//		mkdir($Log_Folder, 0755);
    //	}

		 if(@mkdir($Log_Folder, 0777)) { 
			if(is_dir($LogAFolder)) { 
				@chmod($Log_Folder, 0777); 
			} 
		 } 
 
		$filename = $Log_Folder.'/ContractList_'.date("YmdH").'.php';

		$fp = fopen($filename, "a+");
		fputs ($fp, date("Y-m-d H:i:s")."\r\n");
		fputs ($fp, $string."\r\n\r\n");
		fclose ($fp);

	}catch(Exception $ex){
		
		print_r($ex);
	}
}
?>


<?php
include '../setHeader.php';

//global $keyValue,$iv;
$jsonData			= GetJsonData();

$MainID				=  $jsonData["MainID"];
//페이지
$Page		    	= $jsonData["Page"];
//페이지행
$PageRow		    = $jsonData["PageRow"];
// 2019-10-29 레코드수를 35로 변경하는데 델파이 수정이 아닌 웹페이지수정으로 변경함
$PageRow            = 35;
//매물종류
$ArticleList		 = $jsonData["ArticleList"];
//임대종류
$ArticleType		 = $jsonData["ArticleType"];
//계약일자
$ContractDate		= $jsonData["ContractDate"];
$ContractDate_2   	= $jsonData["ContractDate_2"];
//만기일자
$ManGiDay           = $jsonData["ManGiDay"];
//잔금일자
$RemainderDay		= $jsonData["RemainderDay"];
//처리
$ByelDoCheck        = $jsonData["ByelDoCheck"];
//정렬방식
$SortType			= $jsonData["SortType"];
//오름, 내림
$SortDescAsc		= $jsonData["SortDescAsc"];
//검색방법
$SearchType			= $jsonData["SearchType"];
//검색텍스트
$SearchText			=  ($jsonData['SearchText']);
//완료계약제외
$OanRyoCheck		= $jsonData["OanRyoCheck"];
//리스트에서 스크롤 여부
$MouseScrollAction			= $jsonData["MouseScrollAction"];
//전체레코드수
$TotalDataCount				= $jsonData["TotalDataCount"];
//중개업소 계약서 전송 방식
$SendType					= $jsonData["SendType"];

//타이틀클릭시 선택한 필드
$GridTitleClickField		= $jsonData["GridTitleClickField"];
//정렯방식
$GridTitleClickFieldSortType= $jsonData["GridTitleClickFieldSortType"];
//중계종류
$JointCheck					= $jsonData["JointCheck"];
//5년전 계약서
$FivePreDataCheck			= $jsonData["FivePreDataCheck"];


/*
$StartCount					= ( ($Page-1) * $PageRow) + 1;
$EndCount					= ( ($Page-1) * $PageRow) + $PageRow;
if($Page > 1 )
			$Page = $Page-1;
else		$Page = $Page;
$EndCount					= ( ($Page) * $PageRow) + $PageRow;
//$StartCount					= $Page;
*/

$Field = "a.PK_ID,  CASE WHEN ArticleType = '1801' THEN 
		Case When NationalType= '0' Then '전대차(주택)' 
			else  Case When NationalType= '1' Then '전대차(상가)'  
			else  Case When NationalType= '2' Then '전대차(공장)'
			else  Case When NationalType= '3' Then '전대차(창고)' 
			else  Case When NationalType= '4' Then '전대차(산업지식센터)' 
			else  '전대차('+LTrim(NationalType) +  ')'
		end end end end end  
		else CASE WHEN   ArticleType = '141' THEN '권리양도' ELSE CASE WHEN   ArticleType = '2401' THEN '권리양도(직거래)' ELSE  CASE WHEN   ArticleType = '301' THEN '부동산' ELSE CASE WHEN   ArticleType = '2501' THEN '부동산(직거래)' ELSE  CASE WHEN   ArticleType = '2601' THEN '매매약정서(토지거래허가구역)' ELSE  AptNameTitle END END END END END END  as AptNameTitle  , ArticleType, IsNull(TradeClass,'') as TradeClass, IsNull(Address,'') as  Address, IsNull(DongNo, ' ') AS DongNo, IsNull(HosuNo, ' ') as HosuNo
, /* 2026-10-08 매도인 대리인 이름이 없거나 문자 null이면 괄호 없이 표시함 */ CASE WHEN LTRIM(RTRIM(ISNULL(L_AgentName,''))) = '' OR LOWER(LTRIM(RTRIM(L_AgentName))) = 'null' THEN ISNULL(L_Name,'') ELSE ISNULL(L_Name,'') + '(' + L_AgentName + ')' END AS L_Name 
,isNull(dbo.fn_DecryptByPass(L_Phone_E), '') as L_Phone_EA
, /* 2026-10-08 매수인 대리인 이름이 없거나 문자 null이면 괄호 없이 표시함 */ CASE WHEN LTRIM(RTRIM(ISNULL(H_AgentName,''))) = '' OR LOWER(LTRIM(RTRIM(H_AgentName))) = 'null' THEN ISNULL(H_Name,'') ELSE ISNULL(H_Name,'') + '(' + H_AgentName + ')' END AS H_Name 
, isNull(dbo.fn_DecryptByPass(H_Phone_E), '') as H_Phone_EA, IsNull(L_Address, '')  as L_Address, IsNull(H_Address, '') as  H_Address, CASE WHEN (ContractDate = '    -  -  ') OR ContractDate Is null   OR ContractDate  = ''   THEN '입력안함' ELSE REPLACE(ContractDate, '--','입력안함')   END as ContractDate, CASE WHEN (MidMoneyDate = '    -  -  ') or (MidMoneyDate is Null)   THEN '' ELSE REPLACE(MidMoneyDate, '--','') END as MidMoneyDate, CASE WHEN (MidMoneyDate2 = '    -  -  ') OR MidMoneyDate2 Is null   THEN ' ' ELSE REPLACE(MidMoneyDate2, '--','') END as MidMoneyDate2, CASE WHEN (EtcDate2  = '    -  -  ')  OR EtcDate2 Is null THEN ' ' ELSE REPLACE(EtcDate2, '--','') END as EtcDate2 , CASE WHEN (EtcDate3  = '    -  -  '  )  OR EtcDate3 Is null THEN ' ' ELSE REPLACE(EtcDate3, '--','') END as EtcDate3 , CASE WHEN (ExpireDate  = '    -  -  ')   OR ExpireDate Is null THEN ' ' ELSE  REPLACE(ExpireDate, '--','') END as ExpireDate , CASE WHEN (RemainderDate  = '    -  -  ')   OR RemainderDate Is null THEN ' ' ELSE  REPLACE(RemainderDate, '--','') END as RemainderDate , c.A_Name  as a_ApNa, CASE When ((RemainderDate <> '') AND (RemainderDate<Convert(varchar(10),GETDATE()+1,120))  and ( ByelDoCheck='F')) then '완료' else CASE WHEN ByelDoCheck='T' then '복사' else '일반' end  end AS ByelDoCheck, CASE WHEN (JointCheck = 'T') or (JointCheck = '2')  THEN '공동' ELSE '단독' END   as JointCheck, CASE WHEN d.A_Bulu = '031' THEN Case when ArticleType='1801' Then '연세' Else  '월세' End  ELSE d.A_Name END   as a_GlNa, NewOld_Gubun, IsNull([SendMainID], '') as SendMainID  ,IsNull([SendSw], '') as SendSw , Convert(varchar(10), a.RegDate, 121) as RegDate 
/*2026-02-03 업체가 완료 대신 전송 업체를 다시 표시하라고 함 (업무번호 12834) */
, Case When IsNull([SendMainID], '') <> '' Then (Select IsNull(REPLACE(REPLACE(IsNull(AgencyName,''), '공인중개사', ''), '사무소',''),'') from view_Member where ID = SendMainID)  Else '' End as  SendName
 /*2025-12-31 업체명대신 완료라고 하라고 함 */
/*, Case When IsNull([SendMainID], '') <> '' Then '완료' else '' end SendName */
, Convert(varchar(10), a.EditDate, 121) as EditDate 
,IsNull(ContractDataChangeSw, '0') as ContractDataChangeSw
From table_contract  a With(NOLOCK)   LEFT JOIN (Select A_Code,A_Name, A_Bulu from ArticleTypeMenu With(NOLOCK) ) c On c.A_Code='001' and c.A_Bulu=a.ArticleType  LEFT JOIN (Select A_Code,A_Name, A_Bulu from ArticleTypeMenu) d ON d.A_Code='011' and d.A_Bulu=a.TradeClass ";

	 
$strFilter = " a.MainID = '$MainID'    ";


//매물
if(Trim($ArticleList) != '000') {
			if( strpos(Trim($ArticleList), '971') !== false || strpos(Trim($ArticleList),'1501') !== false) 
			{
					$ArticleList .= ',971,1501,1601,1701';	
			}
			/*
			else if( strpos(Trim($ArticleList), '141') !== false) 
			{
					$ArticleList .= ',141,2401';	
			}
			else if( strpos(Trim($ArticleList), '301') !== false) 
			{
					$ArticleList .= ',301,2501';	
			}
			*/
			else if( strpos(Trim($ArticleList), '1601') !== false) 
			{
					$ArticleList .= ',971,1501,1601,1701';	
			}
			else if( strpos(Trim($ArticleList), '2701') !== false) 
			{
					$ArticleList .= ',971,1501,1601,1701,1901,2701';	
			}			else if( strpos(Trim($ArticleList), '1701') !== false) 
			{
					$ArticleList .= ',971,1501,1601,1701';	
			}
			else if( strpos(Trim($ArticleList), '1401') !== false || strpos(Trim($ArticleList),'571') !== false) 
			{
					$ArticleList .= ',571,1401';	
			}
			else if( strpos(Trim($ArticleList), '671') !== false || strpos(Trim($ArticleList),'771') !== false) 
			{
					$ArticleList .= ',031,224,871,1071';	
			}
			else if( strpos(Trim($ArticleList), '1281') !== false ) 
			{
					$ArticleList .= ',003';	
			}
			else if( strpos(Trim($ArticleList), '1291') !== false ) 
			{
					$ArticleList .= ',187';	
			}
			else if( strpos(Trim($ArticleList), '1301') !== false ) 
			{
					$ArticleList .= ',216';	
			}
			else if( strpos(Trim($ArticleList), '571') !== false ) 
			{
					$ArticleList .= ',1171';	
			}
			else if( strpos(Trim($ArticleList), '331') !== false ) 
			{
					$ArticleList .= ',2001';	
			}
			$ArticleTypeFitter = " and (";
			$ItemTypeA = explode(",",  $ArticleList);
			for($i=0 ; $i<=count($ItemTypeA)-1; $i++){
			    $ItemTypeB = explode("-",  $ItemTypeA[$i]);
				if( Trim($ItemTypeB[0]) != '')
				{
					$ArticleTypeFitter .= " (ArticleType = '$ItemTypeB[0]')  or";	
				}
			}
			$ArticleTypeFitter = substr($ArticleTypeFitter,1, StrLen($ArticleTypeFitter)-3);
			$ArticleTypeFitter .=  " ) ";
			$strFilter .= $ArticleTypeFitter;
}
//iwrite($ArticleTypeFitter);
//임대
if(Trim($ArticleType) != '000') {
//	$strFilter .= " and TradeClass = '$ArticleType' ";
	$TradeTypeFitter = " and (";
	$ItemTypeA = explode(",",  $ArticleType);
	for($i=0 ; $i<=count($ItemTypeA)-1; $i++){
		$ItemTypeB = explode("-",  $ItemTypeA[$i]);
		$TradeTypeFitter .= " (TradeClass = '$ItemTypeB[0]')  or";	
	}
	$TradeTypeFitter = substr($TradeTypeFitter,1, StrLen($TradeTypeFitter)-3);
	$TradeTypeFitter .=  " ) ";
	$strFilter .= $TradeTypeFitter;
}


//iwrite($ArticleType. " 2 = 2  ". $TradeTypeFitter);
//계약일자
if((Trim($ContractDate) != '') && (Trim($ContractDate_2) != '')) {
	//$strFilter .= " and ContractDate >= '$ContractDate' ";
	$strFilter .= " and (ContractDate between  '$ContractDate' and  '$ContractDate_2' )";
}
//만기일자. 중도금일자, 잔금일자
if(Trim($ManGiDay) != '') {
	$strFilter .= " and ( TradeClass <> '001')  and   (etcDate2 >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and etcDate2 <=  convert(varchar(10), DATEadd(day, $ManGiDay, getdate())  ,120))";
	/*
	$strFilter .= " and (  (etcDate2 >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and etcDate2 <=  convert(varchar(10), DATEadd(day, $ManGiDay, getdate())  ,120))";

	$strFilter .= " or (MidMoneyDate >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and MidMoneyDate <=  convert(varchar(10), DATEadd(day, $ManGiDay, getdate())  ,120))";

	$strFilter .= " or (MidMoneyDate2 >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and MidMoneyDate2 <=  convert(varchar(10), DATEadd(day, $ManGiDay, getdate())  ,120))";

	$strFilter .= " or (RemainderDate >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and RemainderDate <=  convert(varchar(10), DATEadd(day, $ManGiDay, getdate())  ,120))  )";
	*/
}

// 잔금일자
if(Trim($RemainderDay) != '') {
	$strFilter .= " and (RemainderDate >=  convert(varchar(10), DATEadd(day, 0, getdate())  ,120) and RemainderDate <=  convert(varchar(10), DATEadd(day, $RemainderDay, getdate())  ,120))";
}


//처리
if(Trim($ByelDoCheck) != '') {
	if(Trim($ByelDoCheck) == 1) 
		$strFilter .= " and ( (RemainderDate>Convert(varchar(10),GETDATE()+1,120) or RemainderDate = '') and ByelDoCheck = 'F')  ";
	else if(Trim($ByelDoCheck) == 2) 
		$strFilter .= " and  ByelDoCheck = 'T'  ";
	else if(Trim($ByelDoCheck) == 3) 
		$strFilter .= " and  ((RemainderDate <> '') AND (RemainderDate<Convert(varchar(10),GETDATE()+1,120))  and ( ByelDoCheck='F'))  ";
}

//중계종류
if(Trim($JointCheck) != '0' && Trim($JointCheck) != '') {
	$strFilter .= " and ( JointCheck = '$JointCheck' )  ";
}

//2026-01-21 5년경과된 계약서 조회 여부
if($FivePreDataCheck == 'T')  
{
		$strFilter .= " and a.RegDate < DATEADD(YEAR, -5, CONVERT(VARCHAR(10), GETDATE(), 121)) ";
}


//정렬방식
/*
계약일자순
등록일자순(PK_ID)
매물종류순
거래종류순
매도인순
매수인순
만기일순
주소순
잔금일자
*/

// 2026-10-09 기본 정렬 기준일. 해당 날짜(2025-09-01)도 이후 그룹에 포함합니다.
$BaseMaxDate = '2025-09-01';

// 열 제목을 클릭하지 않은 경우에만 기본 정렬을 만듭니다.
if (Trim($GridTitleClickField) == '')
{
    // 아래 변수는 날짜 값이 아니라 SQL Server에서 계산할 SQL 표현식입니다.
    // NULL, 일반 공백, 탭, 줄바꿈을 정리한 값을 모든 날짜 판정에서 공통 사용합니다.
    $ContractDateSortValue = "REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(a.ContractDate,''), ' ', ''), CHAR(9), ''), CHAR(13), ''), CHAR(10), '')";
    // 빈 값 또는 하이픈만 남은 값은 미입력입니다. 날짜의 길이보다 먼저 판정합니다.
    $ContractDateMissing = "REPLACE($ContractDateSortValue, '-', '') = ''";

    // 기존 첫 번째 CASE의 의도를 유지하되, 공백 날짜가 길이 10으로 오분류되는 문제를 수정합니다.
    // 그룹 0: 기준일 이후 등록 + 계약일자 미입력
    // 그룹 1: 길이 10 이상인 계약일자(등록일 무관), 또는 기준일 이후의 짧은 계약일자
    // 그룹 2: 기준일 이전 등록 + 짧은 계약일자 또는 미입력
    // 각 그룹에서는 길이 10 이상 / 연월 등 짧은 입력 / 미입력을 구분합니다.
    // 날짜 입력값은 기존처럼 YYYY-MM-DD 또는 YYYY-MM 형식이라는 전제입니다.
    // 길이 구분은 달력상 유효한 날짜를 검증하는 기능은 아닙니다.
    // 계약일자가 같거나 모두 미입력이면 수정일자 최신순, 이어서 PK_ID 큰 순입니다.
    $strSort = " ORDER BY
        CASE
            WHEN a.RegDate >= '$BaseMaxDate' AND ($ContractDateMissing)
                THEN 0
            WHEN NOT ($ContractDateMissing) AND LEN($ContractDateSortValue) >= 10
                THEN 1
            WHEN a.RegDate >= '$BaseMaxDate'
                THEN 1
            ELSE 2
        END ASC,
        CASE
            WHEN ($ContractDateMissing) THEN 2
            WHEN LEN($ContractDateSortValue) >= 10 THEN 0
            ELSE 1
        END ASC,
        CASE
            WHEN ($ContractDateMissing) THEN NULL
            ELSE $ContractDateSortValue
        END DESC,
        a.EditDate DESC,
        a.PK_ID DESC ";

    // 정렬 메뉴 1~9 선택 시 위 기본 정렬을 선택 정렬로 대체합니다.
	if(Trim($SortType) == 1) 
		$strSort	= "order By EDITDATE   $SortDescAsc ,PK_ID DESC ";
	else if(Trim($SortType) == 2) 
		$strSort	= "order By AptNameTitle   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 3) 
		$strSort	= "order By TradeClass   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 4) 
		$strSort	= "order By L_Name   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 5) 
		$strSort	= "order By H_Name   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 6) 
		$strSort	= "order By ExpireDate   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 7) 
		$strSort	= "order By DongNo   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 8) 
		$strSort	= "order By Address   $SortDescAsc ,PK_ID  DESC ";
	else if(Trim($SortType) == 9) 
		$strSort	= "order By RemainderDate   $SortDescAsc ,PK_ID  DESC ";
} Else {
	$GridTitleClickField = 	str_replace('d.K_Bulu','TradeClass',  $GridTitleClickField);
//	$GridTitleClickField = 	str_replace('SendName',  '(select  IsNull(REPLACE(REPLACE(IsNull(AgencyName,''), '공인중개사', ''), '사무소',''),'') from view_Member where ID = SendMainID )',  $GridTitleClickField);
	$ChangeStr = '(select Top 1 AgencyName from view_Member where ID = SendMainID )'; 
	$GridTitleClickField = 	str_replace('SendName',  $ChangeStr,  $GridTitleClickField);

	$ChangeStr = 'dbo.fn_DecryptByPass(L_Phone_E)'; 
	$GridTitleClickField = 	str_replace('L_Phone_EA',  $ChangeStr,  $GridTitleClickField);


	$strSort	= "order By $GridTitleClickField   $GridTitleClickFieldSortType, PK_ID  $GridTitleClickFieldSortType ";
}


//$strSort	= "order by pk_id desc";
//$strSort	= "order By ContractDate desc ";


/*
매도인
매수인
임대인
임차인
소재지
동수
호수
계약일자
잔금일자
만료일자
매도인전화
매수인전화
임대인전화
임차인전화
매도인주소
매수인주소
임대인주소
임차인주소

*/
/*
if(Trim($SearchText)  != '' ){
	switch((int)$SearchType) {
			case 0:	    $strFilter .= " and  ( TradeClass = '001' and REPLACE(a.L_Name, ' ','') LIKE '%$SearchText%') "; break; 
			case 1 :	$strFilter .= " and  ( TradeClass = '001' and REPLACE(a.H_Name, ' ','') LIKE '%$SearchText%') "; break; 
			case 2:	    $strFilter .= " and  ( TradeClass <> '001' and REPLACE(a.L_Name, ' ','') LIKE '%$SearchText%') "; break; 
			case 3 :	$strFilter .= " and  ( TradeClass <> '001' and REPLACE(a.H_Name, ' ','') LIKE '%$SearchText%') "; break; 
			case 4 :	$strFilter .= " and  a.Address LIKE '%$SearchText%' "; break;
			case 5 :	$strFilter .= " and  a.DongNo LIKE '%$SearchText%' "; break;
			case 6 :	$strFilter .= " and  a.HosuNo LIKE '%$SearchText%' "; break;
			case 7 :	$strFilter .= " and  a.ContractDate LIKE '%$SearchText%' "; break;
			case 8 :	$strFilter .= " and  a.RemainderDate LIKE '%$SearchText%' "; break;
			case 9 :    $strFilter .= " and  a.ExpireDate LIKE '%$SearchText%' "; break;
			case 10 :	$strFilter .= " and  ( TradeClass = '001' and (dbo.fn_DecryptByPass(a.L_Phone_E) LIKE '%$SearchText%' or dbo.fn_DecryptByPass(a.L_AgentPhone_E) LIKE '%$SearchText%')      ) "; break;
			case 11 :	$strFilter .= " and  ( TradeClass = '001' and (dbo.fn_DecryptByPass(a.H_Phone_E) LIKE '%$SearchText%' or dbo.fn_DecryptByPass(a.H_AgentPhone_E) LIKE '%$SearchText%')      )" ; break;
			case 12 :	$strFilter .= " and  ( TradeClass <> '001' and (dbo.fn_DecryptByPass(a.L_Phone_E) LIKE '%$SearchText%' or dbo.fn_DecryptByPass(a.L_AgentPhone_E) LIKE '%$SearchText%')     )"; break;
			case 13 :	$strFilter .= " and  ( TradeClass <> '001' and (dbo.fn_DecryptByPass(a.H_Phone_E) LIKE '%$SearchText%' or a.dbo.fn_DecryptByPass(H_AgentPhone_E) LIKE '%$SearchText%')     )"; break;
			case 14 :	$strFilter .= " and  ( TradeClass = '001' and (a.L_Address LIKE '%$SearchText%' or a.L_AgentAddress LIKE '%$SearchText%')  ) "; break;
			case 15 :	$strFilter .= " and  ( TradeClass = '001' and (a.H_Address LIKE '%$SearchText%' or a.H_AgentAddress LIKE '%$SearchText%')  )"; break;
			case 16 :	$strFilter .= " and  ( TradeClass <> '001' and (a.L_Address LIKE '%$SearchText%' or a.L_AgentAddress LIKE '%$SearchText%') ) "; break;
			case 17 :	$strFilter .= " and  ( TradeClass <> '001' and (a.H_Address LIKE '%$SearchText%' or a.H_AgentAddress LIKE '%$SearchText%') ) "; break;
	}
}
*/

/* 2016-06-17 아래와 같이 검색방법으로 수정한다
부동산주소
동수
호수
고객이름
고객전화
고객주소
*/

/*
if(Trim($SearchText)  != '' ){
	switch((int)$SearchType) {
			case 0 :	$strFilter .= " and  a.Address LIKE '%$SearchText%' "; break;
			case 1 :	$strFilter .= " and  a.DongNo LIKE '%$SearchText%' "; break;
			case 2 :	$strFilter .= " and  a.HosuNo LIKE '%$SearchText%' "; break;
			case 3:	    $strFilter .= " and ( ( REPLACE(a.L_Name, ' ','') LIKE '%$SearchText%') "; 
							$strFilter .= " or  (  REPLACE(a.H_Name, ' ','') LIKE '%$SearchText%') "; 
							$strFilter .= " or  ( REPLACE(a.L_Name, ' ','') LIKE '%$SearchText%') ";
							$strFilter .= " or  (  REPLACE(a.H_Name, ' ','') LIKE '%$SearchText%')  or (   REPLACE(a.YoungSuin, ' ','') LIKE '%$SearchText%' ) )";  break;
			case 4 :	$strFilter .= " and ( ( (dbo.fn_DecryptByPass(a.L_Phone_E) LIKE '%$SearchText%' )) ";
			                $strFilter .= " or  ( (dbo.fn_DecryptByPass(a.H_Phone_E) LIKE '%$SearchText%' ))" ;
			                $strFilter .= " or  ( (dbo.fn_DecryptByPass(a.L_Phone_E) LIKE '%$SearchText%' ))"; 
			                $strFilter .= " or  ( (dbo.fn_DecryptByPass(a.H_Phone_E) LIKE '%$SearchText%'  ))"; 
			                $strFilter .= " or  ( (dbo.fn_DecryptByPass(a.H_AgentPhone_E) LIKE '%$SearchText%'))  )"; break;
			case 5 :	$strFilter .= " and ( ( (a.L_Address LIKE '%$SearchText%' or a.L_AgentAddress LIKE '%$SearchText%')  ) ";
			                $strFilter .= " or  ( (a.H_Address LIKE '%$SearchText%' or a.H_AgentAddress LIKE '%$SearchText%')  )";
			                $strFilter .= " or  ( (a.L_Address LIKE '%$SearchText%' or a.L_AgentAddress LIKE '%$SearchText%') ) ";
			                $strFilter .= " or  ( (a.H_Address LIKE '%$SearchText%' or a.H_AgentAddress LIKE '%$SearchText%') )) "; break;
	}
}
*/
// 2026-10-08 계약서 및 별지(table_contract_belji) 통합 검색
// 별지에 여러 행이 있어도 계약서 목록과 건수 중복을 방지하기 위해 EXISTS 사용
// 검색어가 비어 있으면 SQL 검색 조건을 추가하지 않는다.
// Delphi: if Trim(SearchText) <> '' then begin ... end;
if (Trim($SearchText) != '') {
    // 2026-10-08 SQL 문자열 내 작은따옴표 이스케이프 및 공백 무시 검색
    // str_replace(찾을값, 바꿀값, 원본문자열): 작은따옴표 1개를 2개로 만든다
    // 예: O'Brien -> O''Brien. 단, 이것만으로 SQL 인젝션 방지가 완성되지는 않으므로 매개변수 바인딩 권장
    $SearchText = str_replace("'", "''", $SearchText);
    // 2026-10-08 preg_replace: 정규표현식으로 공백/탭/줄바꿈 등을 제거
    // 예: '홍 길 동' -> '홍길동'. /\s+/u에서 \s=공백류, +=1회 이상, u=UTF-8
    $SearchText_2 = preg_replace('/\s+/u', '', $SearchText);
    // 2026-10-08 전화번호 검색은 '-' 및 공백을 빼서 01012345678처럼 비교
    // array(...)는 여러 값을 담은 배열입니다. Delphi TStringList의 항목 목록과 비슷.
    $SearchPhone = str_replace(array('-', ' ', "\t", "\r", "\n"), '', $SearchText);

    // 2026-10-08 검색 대상과 검색 방식을 담을 변수 초기화.
    // array(): 빈 배열. Delphi의 TStringList.Create로 빈 목록을 만드는 개념과 비슷
    // mainFields: table_contract(a)의 컬럼 / beljiFields: table_contract_belji(b)의 컬럼
    $mainFields = array();
    $beljiFields = array();
    // 2026-10-08 별지의 Gubun 필터를 담을 SQL 문자열 예: AND b.Gubun IN ('001','002')
    $beljiGubun = '';
    // 2026-10-08 true면 전화번호용(하이픈/공백 제거), false면 일반 문자열용 LIKE를 생성
    $phoneSearch = false;

    // 2026-10-08 검색 구분(SearchType)에 따라 검색할 필드를 선택
    // (int)는 PHP 정수 형변환. switch/case/break는 Delphi의 case 문과 유사
    // 주의: 여기서는 필드 목록만 지정하며, 아직 DB 조회를 실행하지 않는다.
    // Gubun은 전달된 자료 기준: 001/002=계약 당사자, 003=중개업소, 004=부동산 관련 별지
    switch ((int)$SearchType) {
        // 2026-10-08 소재지 검색: 계약서 소재지 + 부동산 별지(004)의 주소/시/구/동/지번
        case 0: // 부동산 주소
            $mainFields = array('a.Address');
            $beljiFields = array('b.J_Address', 'b.J_Si', 'b.J_Gu', 'b.J_Dong', 'b.J_JiBun');
            $beljiGubun = " AND b.Gubun = '004'";
            break;
        // 2026-10-08 예: '905' 검색 시 DongNo뿐 아니라 '905동'이 적힌 고객/대리인 주소도 검사.
        // 예: 매수인 별지(002) J_Address='...905동 2205호'도 포함해야 하므로 002를 제외하면 안된다.
        case 1: // 2026-10-08 동수 검색 시 계약 당사자/대리인 주소 및 별지 001/002/004 포함
            $mainFields = array('a.DongNo', 'a.Address', 'a.L_Address', 'a.H_Address', 'a.L_AgentAddress', 'a.H_AgentAddress');
            $beljiFields = array('b.J_Address', 'b.J_Dong');
            $beljiGubun = " AND b.Gubun IN ('001','002','004')";
            break;
        // 2026-10-08 호수 검색도 별지 주소 전체에 호수가 들어 있는 경우를 포함
        case 2: // 2026-10-08 호수 검색 시 계약 당사자/대리인 주소 및 별지 001/002/004 포함
            $mainFields = array('a.HosuNo', 'a.Address', 'a.L_Address', 'a.H_Address', 'a.L_AgentAddress', 'a.H_AgentAddress');
            $beljiFields = array('b.J_Address');
            $beljiGubun = " AND b.Gubun IN ('001','002','004')";
            break;
        // 2026-10-08 L/H 고객 이름 및 대리인 이름 + 별지의 J_Name/j_Name_2를 함께 찾는다
        case 3: // 고객 이름 및 대리인 이름, 별지 성명
            $mainFields = array('a.L_Name', 'a.H_Name', 'a.L_AgentName', 'a.H_AgentName', 'a.YoungSuin');
            $beljiFields = array('b.J_Name', 'b.j_Name_2');
            $beljiGubun = " AND b.Gubun IN ('001','002')";
            break;
        // 2026-10-08 dbo.fn_DecryptByPass는 SQL Server에서 암호화된 전화번호를 복호화하는 함수
        // PHP에서 복호화하는 것이 아니며, SQL 문장에 함수 호출을 포함
        case 4: // 고객 및 대리인 전화, 별지 전화(암호화/일반)
            $mainFields = array('dbo.fn_DecryptByPass(a.L_Phone_E)', 'dbo.fn_DecryptByPass(a.L_AgentPhone_E)',
                                'dbo.fn_DecryptByPass(a.H_Phone_E)', 'dbo.fn_DecryptByPass(a.H_AgentPhone_E)');
            $beljiFields = array('dbo.fn_DecryptByPass(b.J_Tel_E)', 'dbo.fn_DecryptByPass(b.J_Phone_E)', 'b.J_Tel', 'b.J_Phone');
            $beljiGubun = " AND b.Gubun IN ('001','002','003')";
            $phoneSearch = true;
            break;
        // 2026-10-08 고객 주소 검색: 본문 L/H 주소와 양쪽 대리인 주소, 별지 001/002 주소
        case 5: // 고객 및 대리인 주소, 별지 고객 주소
            $mainFields = array('a.L_Address', 'a.H_Address', 'a.L_AgentAddress', 'a.H_AgentAddress');
            $beljiFields = array('b.J_Address', 'b.J_Si', 'b.J_Gu', 'b.J_Dong');
            $beljiGubun = " AND b.Gubun IN ('001','002')";
            break;
        // 2026-10-08 사무소명과 별지 003의 상호/성명을 검색
        case 6: // 중개업소명, 별지 중개업소 상호 및 대표자
            $mainFields = array('a.OfficeName', 'a.OfficeName1');
            $beljiFields = array('b.J_SangHo', 'b.J_Name');
            $beljiGubun = " AND b.Gubun = '003'";
            break;
    }

    // 2026-10-08 등록된 검색 필드가 있을 때만 검색 SQL을 생성
    // count(배열)는 항목 개수 / Delphi TStringList.Count와 비슷
    // SearchType이 0~6 밖이면 배열이 비어 있으므로 검색 조건을 만들지 않는다
    if (count($mainFields) > 0) {
        // 2026-10-08 각 필드별 LIKE 문장을 저장할 배열
        // 예: ["a.L_Name LIKE '%김%'", "a.H_Name LIKE '%김%'"]처럼 조건을 차곡차곡 담는다
        $mainConditions = array();
        $beljiConditions = array();
        // 2026-10-08 foreach(배열 as 항목): 배열의 값을 순서대로 $field에 꺼낸다
        // Delphi: for i := 0 to Fields.Count-1 do Field := Fields[i]; 와 비슷
        // $mainConditions[] = ... 는 배열 끝에 항목을 추가하는 문법(TStringList.Add와 유사)
        foreach ($mainFields as $field) {
            // 2026-10-08 phoneSearch=true일 때만 '-'와 스페이스를 제거하고 LIKE 비교.
            if ($phoneSearch) {
                $mainConditions[] = "REPLACE(REPLACE(ISNULL($field,''),'-',''),' ','') LIKE '%$SearchPhone%'";
            } else {
                $mainConditions[] = "(ISNULL($field,'') LIKE '%$SearchText%' OR REPLACE(ISNULL($field,''),' ','') LIKE '%$SearchText_2%')";
            }
        }
        // 2026-10-08 같은 방식으로 별지(b)의 검색 조건도 각각 생성
        // 본문과 별지의 조건을 별도 배열로 유지해야 EXISTS 안팎에 올바르게 넣을 수 있다
        foreach ($beljiFields as $field) {
            if ($phoneSearch) {
                $beljiConditions[] = "REPLACE(REPLACE(ISNULL($field,''),'-',''),' ','') LIKE '%$SearchPhone%'";
            } else {
                $beljiConditions[] = "(ISNULL($field,'') LIKE '%$SearchText%' OR REPLACE(ISNULL($field,''),' ','') LIKE '%$SearchText_2%')";
            }
        }
        // 2026-10-08 별지에서 일치하는 행이 '존재'하는지 EXISTS로 확인
        // EXISTS(SELECT 1 ...): 반환 컬럼을 사용하는 것이 아니라 해당 조건의 행 존재 여부 검사
        // JOIN과 달리 일치하는 별지 행이 여럿이어도 계약서 목록 행 자체를 중복시키지 않는다
        // b.PK_ID_Key = a.PK_ID 관계를 이용합니다. LTRIM/RTRIM은 양쪽 공백 제거함
        // CONVERT(VARCHAR(30),a.PK_ID)는 숫자 PK_ID를 문자열로 변환
        // 실제 DB에서 이 연결 키가 정확하고 고유한지 확인하는 것이 중요
        // implode(' OR ', 배열): 배열 문자열들 사이에 ' OR '를 삽입해 하나의 문자열로 만듡다
        // 예: ['조건A','조건B'] -> '조건A OR 조건B'. Delphi TStringList를 구분자로 합치는 개념
        // 2026-10-08 PK_ID_Key의 뒤쪽 공백을 제거하여 계약서 PK_ID와 연결
        $beljiExists = "EXISTS (SELECT 1 FROM table_contract_belji b WITH(NOLOCK) " .
                       "WHERE LTRIM(RTRIM(b.PK_ID_Key)) = CONVERT(VARCHAR(30),a.PK_ID) " .
                       $beljiGubun . " AND (" . implode(' OR ', $beljiConditions) . "))";
        // 2026-10-08 본문 조건과 별지 EXISTS 조건을 OR로 연결
        // PHP의 . 는 문자열 연결(Delphi의 +), .= 는 원래 문자열 뒤에 덧붙인다
        // 최종 구조: 기존 WHERE 필터 AND ( (본문조건1 OR 본문조건2 ...) OR EXISTS(별지조건...) )
        // 이 $strFilter는 뒤쪽 전체 건수(count) 쿼리 및 페이징 목록 쿼리에 공통으로 사용
        $strFilter .= " AND ((" . implode(' OR ', $mainConditions) . ") OR " . $beljiExists . ")";
    }
}


/*
//5년전 계약서
if($FivePreDataCheck != 'NOSEL') {
	$strFilter .= " and   (  CONVERT(varchar(4), a.RegDate ,121) = '$FivePreDataCheck' ) ";
}
*/
//완료계약제외
if($OanRyoCheck == '1') {
	$strFilter .= " and  (  ( (RemainderDate>Convert(varchar(10),GETDATE()+1,120) or RemainderDate = '') and ByelDoCheck = 'F')  or  ByelDoCheck = 'T') ";
}

//중개업소 계약서 전송 방식
/*
if($SendType != '0' ) {
		$strFilter .= " and  ( SendSw = '$SendType') ";
}
*/

$MouseScrollAction = '0';
if ($MouseScrollAction  == '0'){
	$sql = "select  count(*) as TotalCount from table_contract a  With(NOLOCK)  where " . $strFilter;
	$stmt = sqlsrv_query( $dbms2, $sql );//,$params);
	$Response->scroll='yes';
	while( $obj = sqlsrv_fetch_object( $stmt) ){
		$TotalCount = $obj->TotalCount;
		break;
	}
}else {
	$TotalCount = $TotalDataCount;
}



//$TotalCount = 300;


$StartCount					= ( ($Page-1) * $PageRow) + 1;
$EndCount					= ( ($Page-1) * $PageRow) + $PageRow;
if($EndCount > $TotalCount)
   $EndCount = $TotalCount;



//$TotalCount = 100;

$strSQL  = " Select * From (";
$strSQL .= " Select ROW_NUMBER() OVER ({$strSort}) AS RowNum, ";
$strSQL .=  $Field;
$strSQL .= " Where " . $strFilter;
$strSQL .= " ) as X ";
$strSQL .= " Where RowNum BETWEEN {$StartCount} AND {$EndCount} ORDER BY RowNum ASC";

//if($MainID == 'test_hippo')
//		CustomLog($strSQL);


iwrite($strSQL);


$stmt = sqlsrv_query( $dbms2, $strSQL);//,$params);

if( $stmt === false ) {
     die( print_r( sqlsrv_errors(), true));
	iwrite(print_r(sqlsrv_errors(),true));
}


$Count=0;
while( $obj = sqlsrv_fetch_object( $stmt) ){

	//print_r($obj);

	$data[]=$obj;
	//$Count++;
}


$Response->TotalCount=$TotalCount;
$Response->data=$data;
//$Response->strSQL=$strSQL;
//$Response->sCount=$Count;

//DB닫기
dbclose_ms2();

printfView($Response);
//echo $strSQL." = ". $Count;

//if($MainID == 'test_hippo') ||
//if  ($MainID == 'k3s10260')
  CustomLog($strSQL);


?>