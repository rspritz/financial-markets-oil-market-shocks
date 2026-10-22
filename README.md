# financial-markets-oil-market-shocks
In this project, I examine oil market shocks and S&amp;P 500 returns using monthly data from 1990 to 2025. I employ a structural vector autoregression (SVAR) following the approach of Kilian (2009). [Read the full paper (PDF)](paper.pdf)

The main data file (Projectv3.dta) contains the variables that were obtained on a monthly basis. The other two dta files in this folder contain WTI prices and S&P 500 Index values that are observed on a daily basis.

Project_Do_File_Final.do combines these files in the first few lines of code and I have left it like this in
order to show how the two daily series are converted to monthly series.
